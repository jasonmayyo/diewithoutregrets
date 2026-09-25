import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Miniflare, convertV4MiniflareOptions, Response as WorkerResponse } from 'miniflare';
import { createHash, generateKeyPairSync, randomBytes, randomUUID, sign } from 'node:crypto';
import cbor from 'cbor';

test('Worker runtime verifies signed requests, blocks replay/tampering and reserves failed calls', async () => {
  const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const keyID = randomBytes(32).toString('base64');
  const appID = '5BFXSF2PS6.com.jasonmayo.diewithoutregrets';
  let calls = 0;
  const card = { regretPrompt: 'Question?', regret: 'Context', choices: ['Yes', 'No'], correctAnswerIndex: 0, backgroundExplanation: 'Explanation.' };
  const mf = new Miniflare(convertV4MiniflareOptions({
    unsafeInspectDurableObjects: true,
    name: 'studyguard-test', modules: true, scriptPath: 'dist/index.js',
    compatibilityDate: '2026-09-20', compatibilityFlags: ['nodejs_compat'], cf: false,
    durableObjects: { GATE: { className: 'StudyGuardGate', useSQLite: true } },
    bindings: { APP_ID_PREFIX: '5BFXSF2PS6', BUNDLE_ID: 'com.jasonmayo.diewithoutregrets',
      ALLOW_DEVELOPMENT_ATTESTATION: 'false', AI_ENABLED: 'true', OPENAI_API_KEY: 'local-test-only',
      DEVICE_DAILY_LIMIT: '20', GLOBAL_DAILY_LIMIT: '2', GLOBAL_MONTHLY_LIMIT: '20' },
    outboundService: async request => {
      // ALL outbound traffic is intercepted. Tests cannot reach/pay OpenAI.
      assert.equal(request.url, 'https://api.openai.com/v1/chat/completions');
      assert.equal(request.headers.get('authorization'), 'Bearer local-test-only');
      const body = await request.json();
      assert.equal(body.model, 'gpt-4o-mini'); assert.equal(body.n, 1); assert.equal(body.max_tokens, 12000);
      calls++;
      return new WorkerResponse(JSON.stringify({ choices: [{ finish_reason: calls === 2 ? 'length' : 'stop',
        message: { content: JSON.stringify({ cards: Array.from({ length: 50 }, () => card) }) } }] }),
      { headers: { 'Content-Type': 'application/json' } });
    },
  }));
  const post = (path, body, headers = {}) => mf.dispatchFetch(`https://studyguard.test${path}`, {
    method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: typeof body === 'string' ? body : JSON.stringify(body),
  });
  try {
    assert.equal((await mf.dispatchFetch('https://studyguard.test/v1/chat/completions')).status, 404);
    // Keys from before promotion, or a development ledger, cannot authorize
    // production requests even when the same physical Worker is reused.
    for (const name of ['studyguard-v1', 'studyguard-development-v1']) {
      const previous = await mf.unsafeGetDurableObjectStorage('studyguard-test', 'StudyGuardGate', { name });
      await previous.exec('CREATE TABLE IF NOT EXISTS keys (id TEXT PRIMARY KEY, public_key TEXT NOT NULL, counter INTEGER NOT NULL)');
      await previous.exec('INSERT INTO keys VALUES (?, ?, 0)', keyID, publicKey.export({ type: 'spki', format: 'pem' }));
    }
    const initial = await (await post('/v1/challenge', { keyId: keyID })).json();
    assert.equal(initial.purpose, 'attest');
    assert.equal((await post('/v1/attest', { keyId: keyID, challenge: initial.challenge, attestation: 'Zm9yZ2Vk' })).status, 401);
    assert.equal(calls, 0);
    // Seed an already-enrolled public test key through Miniflare's local-only
    // admin storage API. There is NO equivalent route or bypass in the Worker.
    const storage = await mf.unsafeGetDurableObjectStorage('studyguard-test', 'StudyGuardGate', { name: 'studyguard-production-v1' });
    await storage.exec('INSERT INTO keys VALUES (?, ?, 0)', keyID, publicKey.export({ type: 'spki', format: 'pem' }));
    let counter = 0;
    const signedRequest = async () => {
      const challenge = await (await post('/v1/challenge', { keyId: keyID })).json();
      assert.equal(challenge.purpose, 'generate');
      const raw = JSON.stringify({ action: 'generate_flashcards', text: 'Photosynthesis converts sunlight into chemical energy stored in plants.',
        language: 'English', challenge: challenge.challenge, requestId: randomUUID() });
      const hash = x => createHash('sha256').update(x).digest();
      const auth = Buffer.alloc(37); hash(appID).copy(auth); auth.writeUInt32BE(++counter, 33);
      const signature = sign('sha256', hash(Buffer.concat([auth, hash(raw)])), privateKey);
      return { raw, headers: { 'X-App-Attest-Key-ID': keyID,
        'X-App-Attest-Assertion': cbor.encode({ signature, authenticatorData: auth }).toString('base64') } };
    };
    const first = await signedRequest();
    const response = await post('/v1/flashcards', first.raw, first.headers);
    assert.equal(response.status, 200, JSON.stringify({ response: await response.clone().text(), upstreamCalls: calls, reservations: await storage.exec('SELECT * FROM inflight') }));
    assert.equal((await response.json()).cards.length, 50);
    assert.equal(calls, 1);
    assert.equal((await post('/v1/flashcards', first.raw, first.headers)).status, 401);
    assert.equal(calls, 1);
    const tampered = await signedRequest();
    assert.equal((await post('/v1/flashcards', tampered.raw.replace('Photosynthesis', 'Modified text'), tampered.headers)).status, 401);
    assert.equal(calls, 1);
    const truncated = await signedRequest();
    assert.equal((await post('/v1/flashcards', truncated.raw, truncated.headers)).status, 502);
    assert.equal(calls, 2);
    const overBudget = await signedRequest();
    assert.equal((await post('/v1/flashcards', overBudget.raw, overBudget.headers)).status, 429);
    assert.equal(calls, 2);
  } finally { await mf.dispose(); }
});
