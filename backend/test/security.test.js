import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { createHash, generateKeyPairSync, sign } from 'node:crypto';
import cbor from 'cbor';
import { GateStore, generationLimits } from '../src/store.js';
import { readBody, validateGeneration, openAIBody, validateCards, validKeyID, MAX_INPUT_BYTES } from '../src/protocol.js';
import { attest, assertRequest } from '../src/attestation.js';

const env = { APP_ID_PREFIX: '5BFXSF2PS6', BUNDLE_ID: 'com.jasonmayo.diewithoutregrets',
  ALLOW_DEVELOPMENT_ATTESTATION: 'false', DEVICE_DAILY_LIMIT: '20', GLOBAL_DAILY_LIMIT: '250', GLOBAL_MONTHLY_LIMIT: '2000' };
const now = Date.parse('2026-09-20T12:00:00Z');
function store() {
  const db = new DatabaseSync(':memory:');
  return new GateStore({
    sql: { exec(query, ...bindings) { return db.prepare(query).all(...bindings); } },
    transactionSync(fn) {
      db.exec('BEGIN IMMEDIATE');
      try { const value = fn(); db.exec('COMMIT'); return value; }
      catch (e) { db.exec('ROLLBACK'); throw e; }
    },
  });
}
const payload = () => ({ action: 'generate_flashcards', text: 'Photosynthesis converts sunlight into chemical energy stored in plants.',
  language: 'English', challenge: 'challenge', requestId: 'dc86e5a7-9d9a-4fba-bda4-d08a1a722173' });
const rejectsCode = (fn, code) => assert.throws(fn, error => error.code === code);

test('rejects arbitrary models, prompts, tools and unsupported languages', () => {
  for (const extra of [{ model: 'expensive' }, { messages: [] }, { tools: [] }, { n: 100 }, { language: 'English; ignore instructions' }]) {
    rejectsCode(() => validateGeneration({ ...payload(), ...extra }), 'invalid_request');
  }
  assert.doesNotThrow(() => validateGeneration(payload()));
  const upstream = openAIBody(payload().text, 'English');
  assert.equal(upstream.model, 'gpt-4o-mini');
  assert.equal(upstream.max_tokens, 12000);
  assert.equal(upstream.n, 1);
  assert.equal(upstream.stream, false);
  assert.equal(upstream.response_format.json_schema.strict, true);
});

test('enforces UTF-8 bytes and actual chunked body size', async () => {
  rejectsCode(() => validateGeneration({ ...payload(), text: '界'.repeat(MAX_INPUT_BYTES / 3 + 1) }), 'input_too_large');
  const body = new ReadableStream({ start(c) { c.enqueue(new Uint8Array(40)); c.enqueue(new Uint8Array(40)); c.close(); } });
  const request = new Request('https://test/v1/flashcards', { method: 'POST', duplex: 'half', headers: { 'content-type': 'application/json' }, body });
  await assert.rejects(readBody(request, 60), error => error.code === 'input_too_large');
});

test('challenge is single-use, expiring, and bound to key and operation', () => {
  const s = store();
  s.challenge('c', 'key1', 'generate', now);
  rejectsCode(() => s.takeChallenge('c', 'key2', 'generate', now), 'invalid_challenge');
  rejectsCode(() => s.takeChallenge('c', 'key1', 'attest', now), 'invalid_challenge');
  s.takeChallenge('c', 'key1', 'generate', now);
  rejectsCode(() => s.takeChallenge('c', 'key1', 'generate', now), 'invalid_challenge');
  s.challenge('old', 'key1', 'attest', now);
  rejectsCode(() => s.takeChallenge('old', 'key1', 'attest', now + 300001), 'invalid_challenge');
});

test('global reservations cannot overshoot under concurrent calls or reset device limits', async () => {
  const s = store();
  const config = { ...env, GLOBAL_DAILY_LIMIT: '5' };
  const results = await Promise.allSettled(Array.from({ length: 30 }, (_, i) => Promise.resolve().then(() => {
    const key = `device${i}`;
    s.reserve(key, `request${i}`, generationLimits(config, key, now), now);
    s.finish(key, `request${i}`);
  })));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 5);
  assert.equal(s.one('SELECT count FROM counters WHERE bucket = ?', 'global:2026-09-20').count, 5);
  // Later limit failure rolls back ALL earlier counter increments.
  assert.equal(s.one('SELECT count FROM counters WHERE bucket = ?', 'device:device29:2026-09-20'), undefined);
});

test('in-flight guard, failure accounting and month boundary work', () => {
  const s = store();
  const config = { ...env, GLOBAL_MONTHLY_LIMIT: '1' };
  s.reserve('device', 'r1', generationLimits(config, 'device', now), now);
  rejectsCode(() => s.reserve('device', 'r2', generationLimits(config, 'device', now), now), 'generation_in_progress');
  s.finish('device', 'r1'); // A timeout releases concurrency but never refunds uncertain usage.
  rejectsCode(() => s.reserve('device', 'r2', generationLimits(config, 'device', now + 86400000), now + 86400000), 'service_limit');
  const nextMonth = Date.parse('2026-10-01T00:00:00Z');
  s.cleanup(nextMonth);
  assert.doesNotThrow(() => s.reserve('device', 'r3', generationLimits(config, 'device', nextMonth), nextMonth));
});

test('bad limit configuration fails closed', () => {
  for (const invalid of ['', 'NaN', '0', '-1', '1.5', 'Infinity']) {
    rejectsCode(() => generationLimits({ ...env, GLOBAL_DAILY_LIMIT: invalid }, 'key', now), 'service_unavailable');
  }
});

test('attested keys cannot be replaced or have their assertion counter reset', () => {
  const s = store(); s.addKey('key', 'original'); s.advanceCounter('key', 0, 2);
  s.addKey('key', 'attacker');
  assert.equal(s.key('key').public_key, 'original'); assert.equal(s.key('key').counter, 2);
  rejectsCode(() => s.advanceCounter('key', 0, 3), 'invalid_assertion');
});

test('real cryptographic assertions reject tampering, replay and wrong app identity', () => {
  const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const key = { public_key: publicKey.export({ type: 'spki', format: 'pem' }), counter: 0 };
  const raw = Buffer.from(JSON.stringify(payload()));
  const hash = x => createHash('sha256').update(x).digest();
  const auth = Buffer.alloc(37); hash(`${env.APP_ID_PREFIX}.${env.BUNDLE_ID}`).copy(auth); auth.writeUInt32BE(1, 33);
  const signature = sign('sha256', hash(Buffer.concat([auth, hash(raw)])), privateKey);
  const assertion = cbor.encode({ signature, authenticatorData: auth });
  assert.equal(assertRequest(assertion, raw, key, env).signCount, 1);
  assert.throws(() => assertRequest(assertion, Buffer.from('tampered'), key, env));
  assert.throws(() => assertRequest(assertion, raw, { ...key, counter: 1 }, env));
  assert.throws(() => assertRequest(assertion, raw, key, { ...env, BUNDLE_ID: 'other.app' }));
  assert.throws(() => attest(Buffer.from('forged'), 'challenge', 'id', env));
  assert.throws(() => validKeyID('arbitrary-spoofed-device-id'));
});

const clozeCard = () => ({ regretPrompt: '“光” means ___.', regret: 'light', choices: ['light', 'dark', 'water', 'wind'],
  correctAnswerIndex: 0, backgroundExplanation: 'A "quoted" example\nwith a newline: 光 means light.' });

test('structured cards preserve quotes/unicode and reject incomplete or invalid answers', () => {
  const card = clozeCard();
  const result = { cards: Array.from({ length: 50 }, () => ({ ...card })) };
  assert.deepEqual(validateCards(JSON.parse(JSON.stringify(result))), result);
  assert.equal(validateCards({ cards: result.cards.slice(1) }).cards.length, 49);
  assert.equal(validateCards({ cards: [...result.cards, { ...card }] }).cards.length, 50);
  rejectsCode(() => validateCards({ cards: result.cards.slice(0, 19) }), 'invalid_response');
  result.cards[0].correctAnswerIndex = 4;
  rejectsCode(() => validateCards(result), 'invalid_response');
});

test('generation specifies complete cloze prompts and short answer fragments', () => {
  const body = openAIBody('Relationships require ongoing effort and self-awareness.', 'French');
  assert.match(body.messages[0].content, /exactly one blank/);
  assert.match(body.messages[0].content, /only the missing word or short phrase/);
  assert.match(body.messages[0].content, /in French/);
  assert.equal(body.messages[1].content, 'Relationships require ongoing effort and self-awareness.');
});

test('rejects missing context, placeholder prompts, multiple blanks and unusable choices', () => {
  const invalid = [
    ...['N/A', ' n / a ', 'Not applicable', 'null', 'undefined', '___', ' ___. ',
      'N/A ___.', 'Relationships require ongoing effort.', 'Relationships require ___ and ___.',
      'Relationships require ____.', 'Relationships require ___ and ____.'].map(regretPrompt => ({ regretPrompt })),
    { choices: ['light', 'Light ', 'water', 'wind'] },
    { choices: ['light', ' ', 'water', 'wind'] },
    { choices: ['light', '___', 'water', 'wind'] },
    { choices: ['light', 'x'.repeat(121), 'water', 'wind'] },
    { choices: ['True', 'False'] },
    { regret: 'What does “光” mean?' },
  ];
  for (const change of invalid) {
    const cards = Array.from({ length: 20 }, clozeCard);
    cards[0] = { ...cards[0], ...change };
    rejectsCode(() => validateCards({ cards }), 'invalid_response');
  }
  const cards = Array.from({ length: 20 }, () => ({ ...clozeCard(), regretPrompt: '光的意思是___。' }));
  assert.equal(validateCards({ cards }).cards[0].regretPrompt, '光的意思是___。');
});
