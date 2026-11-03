import test from 'node:test';
import assert from 'node:assert/strict';
import { requireSafeText, requireRespectfulReply } from '../src/safety.js';
const env = { OPENAI_API_KEY: 'test-only' };
const mock = body => async () => Response.json(body);
test('moderation rejects flagged input or output', async () => {
  await assert.rejects(requireSafeText(env, 'unsafe fixture', mock({ results: [{ flagged: true, categories: { harassment: true } }] })), { code: 'unsafe_content' });
});
test('moderation fails closed on missing, malformed, inconsistent or failed screening', async () => {
  for (const body of [{}, { results: [] }, { results: [{ flagged: false }] },
    { results: [{ flagged: false, categories: {} }] }, { results: [{ flagged: 'false', categories: { harassment: false } }] }]) {
    await assert.rejects(requireSafeText(env, 'fixture', mock(body)), { code: 'safety_unavailable' });
  }
  await assert.rejects(requireSafeText(env, 'fixture', async () => new Response('', { status: 401 })), { code: 'safety_unavailable' });
  await assert.rejects(requireSafeText(env, 'fixture', async () => { throw new Error('network'); }), { code: 'safety_unavailable' });
  await assert.rejects(requireSafeText(env, ['one', 'two'], mock({ results: [{ flagged: false, categories: { harassment: false } }] })), { code: 'safety_unavailable' });
});
test('safe educational replies pass both independent checks', async () => {
  const text = 'Try again. Plants use sunlight to make sugars.';
  requireRespectfulReply(text);
  await requireSafeText(env, text, mock({ results: [{ flagged: false, categories: { harassment: false } }] }));
});
test('documented nullable illicit categories are accepted, other unknown category values fail closed', async () => {
  await requireSafeText(env, 'fixture', mock({ results: [{ flagged: false,
    categories: { harassment: false, illicit: null, 'illicit/violent': null } }] }));
  for (const categories of [{ harassment: null }, { harassment: false, unexpected: null }]) {
    await assert.rejects(requireSafeText(env, 'fixture', mock({ results: [{ flagged: false, categories }] })),
      { code: 'safety_unavailable' });
  }
});
test('product policy rejects demeaning replies even if general moderation misses them', () => {
  for (const text of ['You are worthless and you should give up.', 'You’re useless', 'You are\nworthless', 'Nobody loves you.']) {
    assert.throws(() => requireRespectfulReply(text), { code: 'unsafe_content' });
  }
});
test('moderation diagnostics classify denials without recording provider text or secrets', async t => {
  const log = t.mock.method(console, 'log', () => {});
  for (const body of [{ error: 'Model is blocked for this project. private-fixture' },
    { error: { message: 'Project does not have access to this model. private-fixture', code: 'model_not_found' } }]) {
    await assert.rejects(requireSafeText(env, 'student private-fixture', async () => Response.json(body, { status: 403 })),
      { code: 'safety_unavailable' });
  }
  const entries = log.mock.calls.map(call => JSON.parse(call.arguments[0]));
  assert.equal(entries.length, 2);
  assert.ok(entries.every(entry => entry.cause === 'model_access' && entry.status === 403));
  assert.ok(!JSON.stringify(entries).includes('private-fixture'));
});
