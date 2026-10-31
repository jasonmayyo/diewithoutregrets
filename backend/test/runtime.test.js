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
  let tutorCalls = 0;
  // Distinct cards so the pipeline's dedupe keeps all 50 (identical cards would
  // collapse to one). Card content is irrelevant to the auth/replay/reservation checks.
  const mkCard = i => ({ regretPrompt: `Section fact ${i}: plants capture light energy via the ___ route here.`, regret: `route${i}`,
    choices: [`route${i}`, `cycle${i}`, `phase${i}`, `stage${i}`], correctAnswerIndex: 0,
    backgroundExplanation: `Fact ${i} explains how plants store light energy.`, topic: 'Photosynthesis' });
  const mf = new Miniflare(convertV4MiniflareOptions({
    unsafeInspectDurableObjects: true,
    name: 'studyguard-test', modules: true, scriptPath: 'dist/index.js',
    compatibilityDate: '2026-09-20', compatibilityFlags: ['nodejs_compat'], cf: false,
    durableObjects: { GATE: { className: 'StudyGuardGate', useSQLite: true } },
    bindings: { APP_ID_PREFIX: '5BFXSF2PS6', BUNDLE_ID: 'com.jasonmayo.diewithoutregrets',
      ALLOW_DEVELOPMENT_ATTESTATION: 'false', AI_ENABLED: 'true', OPENAI_API_KEY: 'local-test-only',
      DEVICE_DAILY_LIMIT: '20', GLOBAL_DAILY_LIMIT: '2', GLOBAL_MONTHLY_LIMIT: '20', SCRIPT_GLOBAL_DAILY_LIMIT: '1' },
    outboundService: async request => {
      // ALL outbound traffic is intercepted. Tests cannot reach/pay OpenAI.
      assert.equal(request.url, 'https://api.openai.com/v1/chat/completions');
      assert.equal(request.headers.get('authorization'), 'Bearer local-test-only');
      const body = await request.json();
      assert.equal(body.model, 'gpt-4o-mini'); assert.equal(body.n, 1);
      if (body.response_format.json_schema.name === 'tutor_reply') {
        tutorCalls++;
        assert.equal(body.max_tokens, 500);
        return new WorkerResponse(JSON.stringify({ choices: [{ finish_reason: 'stop', message: {
          content: JSON.stringify({ reply: 'Light supplies energy for photosynthesis.', grant: 999 }),
        } }] }), { headers: { 'Content-Type': 'application/json' } });
      }
      assert.equal(body.max_tokens, 12000);
      calls++;
      return new WorkerResponse(JSON.stringify({ choices: [{ finish_reason: calls === 2 ? 'length' : 'stop',
        message: { content: JSON.stringify({ cards: Array.from({ length: 50 }, (_, i) => mkCard(i)) }) } }] }),
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
    const signedRequest = async (fields = { action: 'generate_flashcards', text: 'Photosynthesis converts sunlight into chemical energy stored in plants.', language: 'English' }) => {
      const challenge = await (await post('/v1/challenge', { keyId: keyID })).json();
      assert.equal(challenge.purpose, 'generate');
      const raw = JSON.stringify({ ...fields, challenge: challenge.challenge, requestId: randomUUID() });
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
    const tutor = { action: 'ask_tutor', persona: 'willow', question: 'Why?', history: Array.from({ length: 4 }, () => ({ question: 'Why?', reply: '解'.repeat(2000) })),
      card: { prompt: 'Plants absorb ___.', answer: 'light', explanation: '光'.repeat(4000) } };
    const followup = await signedRequest(tutor);
    assert.ok(Buffer.byteLength(followup.raw) > 32_768, 'bounded Unicode context exceeds the small script body limit');
    const tutorResponse = await post('/v1/tutor', followup.raw, followup.headers);
    assert.equal(tutorResponse.status, 200);
    assert.deepEqual(await tutorResponse.json(), { reply: 'Light supplies energy for photosynthesis.' });
    assert.equal(tutorCalls, 1);
    assert.equal((await post('/v1/tutor', followup.raw, followup.headers)).status, 401);
    const secondTutor = await signedRequest(tutor);
    assert.equal((await post('/v1/tutor', secondTutor.raw, secondTutor.headers)).status, 429);
    const script = await signedRequest({ action: 'generate_script', context: {
      persona: 'willow', mood: 'chill', app: 'your apps', gateCount: 1, questions: 3, minutes: 6,
    } });
    assert.equal((await post('/v1/script', script.raw, script.headers)).status, 429, 'tutor shares the script ceiling');
    assert.equal(tutorCalls, 1);
  } finally { await mf.dispose(); }
});
