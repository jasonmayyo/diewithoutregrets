import { test } from 'node:test';
import assert from 'node:assert/strict';
import { chunkText, validateCards, screenCards, validateTutorRequest, openAITutorBody, validateTutorReply } from '../src/protocol.js';
import { callModel, generateFlashcards } from '../src/generation.js';
import { scriptLimits } from '../src/store.js';

const card = i => ({ regretPrompt: `Section ${i}: the stored value is ___ units.`, regret: `value${i}`,
  choices: [`value${i}`, 'alpha', 'beta', 'gamma'], correctAnswerIndex: 0, backgroundExplanation: 'This is the saved fact.', topic: 'Facts' });
const response = value => Response.json({ choices: [{ finish_reason: 'stop', message: { content: JSON.stringify(value) } }] });
const env = { OPENAI_API_KEY: 'test-only' };

test('paragraph packing retains the tail even when packing exceeds the chunk cap', () => {
  const paragraphs = Array.from({ length: 14 }, (_, i) => `Paragraph-${i}: ${'word '.repeat(119)}`);
  const chunks = chunkText(paragraphs.join('\n\n'), 1000, 8);
  assert.ok(chunks.length <= 8);
  for (let i = 0; i < 14; i++) assert.ok(chunks.join('\n').includes(`Paragraph-${i}:`));
});

test('topic results screen and deduplicate without rejecting the remaining usable cards', () => {
  const cards = Array.from({ length: 10 }, (_, i) => card(i));
  cards.push(card(0), null, { ...card(99), choices: 'wrong type' }, { ...card(100), regretPrompt: 'It is ___.' });
  assert.equal(validateCards({ cards }, 10).cards.length, 10);
  assert.throws(() => validateCards({ cards: Array(50).fill(card(0)) }), { code: 'invalid_response' });
  assert.equal(screenCards([{ ...card(1), regret: 'ion', regretPrompt: 'A reaction forms an ___.' }]).length, 1);
});

test('upstream failures remain bounded, correctly classified, and are never retried', async t => {
  for (const [status, code] of [[401, 'service_unavailable'], [429, 'service_busy'], [502, 'service_unavailable']]) {
    const mock = t.mock.method(globalThis, 'fetch', async () => new Response('private provider details', { status }));
    await assert.rejects(callModel(env, {}, 100, 'test'), { code });
    assert.equal(mock.mock.callCount(), 1);
    mock.mock.restore();
  }
  t.mock.method(globalThis, 'fetch', async () => { throw new DOMException('deadline', 'TimeoutError'); });
  await assert.rejects(callModel(env, {}, 100, 'test'), { code: 'generation_timeout' });
});

test('truncated, refused, non-JSON and malformed model responses fail closed', async t => {
  const values = [
    Response.json({ choices: [{ finish_reason: 'length', message: { content: '{}' } }] }),
    Response.json({ choices: [{ finish_reason: 'stop', message: { refusal: 'no', content: '{}' } }] }),
    new Response('bad', { headers: { 'content-type': 'text/html' } }),
    Response.json({ choices: [{ finish_reason: 'stop', message: { content: 'not json' } }] }),
  ];
  t.mock.method(globalThis, 'fetch', async () => values.shift());
  for (let i = 0; i < 4; i++) await assert.rejects(callModel(env, {}, 100, 'test'), { code: 'invalid_response' });
});

test('document generation keeps successful sections, reports gaps, and limits concurrency', async t => {
  let calls = 0, running = 0, peak = 0;
  t.mock.method(globalThis, 'fetch', async (_url, options) => {
    const index = calls++;
    const body = JSON.parse(options.body);
    assert.equal(body.model, 'gpt-4o-mini');
    peak = Math.max(peak, ++running);
    await new Promise(resolve => setTimeout(resolve, 2));
    running--;
    return index === 1 ? new Response('', { status: 503 }) : response({ cards: Array.from({ length: 8 }, (_, i) => card(index * 10 + i)) });
  });
  const result = await generateFlashcards(env, { text: Array.from({ length: 8 }, (_, i) => `Section-${i} ${'material '.repeat(450)}`).join('\n\n'), language: 'English' });
  assert.ok(result.cards.length >= 8 && result.cards.length <= 50);
  assert.ok(calls <= 8 && peak <= 4);
  assert.equal(result.coverage.sections, calls);
  assert.equal(result.coverage.completed, calls - 1);
  assert.ok(result.cards.some(c => c.regret === `value${(calls - 1) * 10}`), 'retain a card from the final section');
});

test('all failed document sections surface the underlying error', async t => {
  t.mock.method(globalThis, 'fetch', async () => new Response('', { status: 429 }));
  await assert.rejects(generateFlashcards(env, { text: 'notes '.repeat(20), language: 'English' }), { code: 'service_busy' });
});

test('tutor only accepts bounded card questions, with no client role/tool overrides', () => {
  const body = { action: 'ask_tutor', persona: 'willow', question: 'Why is that correct?',
    card: { prompt: 'Plants use ___ for photosynthesis.', answer: 'light', explanation: 'Light supplies energy.' },
    history: [], challenge: 'c', requestId: 'dc86e5a7-9d9a-4fba-bda4-d08a1a722173' };
  validateTutorRequest(body);
  for (const change of [{ question: ' ' }, { question: 'x'.repeat(1001) }, { history: Array(5).fill({ question: 'q', reply: 'r' }) },
    { messages: [] }, { model: 'another-model' }, { card: { ...body.card, grant: 999 } },
    { history: [{ role: 'system', question: 'q', reply: 'r' }] }]) {
    assert.throws(() => validateTutorRequest({ ...body, ...change }), { code: 'invalid_request' });
  }
  const request = openAITutorBody(body);
  assert.equal(request.max_tokens, 500);
  assert.equal(request.messages[1].role, 'user');
  assert.deepEqual(JSON.parse(request.messages[1].content).card, body.card);
  assert.deepEqual(validateTutorReply({ reply: ' A short explanation. ', grant: 999 }), { reply: 'A short explanation.' });
  for (const reply of ['', 'x'.repeat(2001), null]) assert.throws(() => validateTutorReply({ reply }), { code: 'invalid_response' });
  assert.ok(scriptLimits({}, 'key', Date.now()).every(limit => limit.bucket.startsWith('script-')));
});
