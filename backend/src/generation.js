import { APIError, readBody, openAIBody, validateCards, chunkText, openAIChunkBody, finalizeChunkedCards } from './protocol.js';

// ---- Generation helpers (module scope; function declarations are hoisted) ----

// One OpenAI chat-completions call: returns the parsed JSON content, or throws an
// APIError. Logs the upstream status on failure (status only, never content) so a
// bad/rotated key (401), quota (429) or outage (5xx) is visible in observability.
// No automatic retries: a timeout may still have incurred provider usage.
export async function callModel(env, bodyObj, timeoutMs, label) {
  let upstream;
  try { upstream = await fetch('https://api.openai.com/v1/chat/completions', {
    // Workers supports manual redirects; reject any 3xx without forwarding the
    // provider credential or study text to another host.
    method: 'POST', redirect: 'manual', signal: AbortSignal.timeout(timeoutMs),
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${env.OPENAI_API_KEY}` },
    body: JSON.stringify(bodyObj),
  }); } catch (error) {
    const timedOut = error?.name === 'TimeoutError' || error?.name === 'AbortError';
    console.log(JSON.stringify({ event: 'upstream_error', label, reason: timedOut ? 'timeout' : 'network' }));
    throw new APIError(503, timedOut ? 'generation_timeout' : 'service_unavailable');
  }
  if (!upstream.ok) {
    await upstream.body?.cancel();
    console.log(JSON.stringify({ event: 'upstream_error', label, status: upstream.status }));
    throw new APIError(503, upstream.status === 429 ? 'service_busy' : 'service_unavailable');
  }
  let response;
  try { response = (await readBody(upstream, 300_000)).body; }
  catch { throw new APIError(502, 'invalid_response'); }
  const choice = response.choices?.[0];
  // Diagnostics only: counts and reasons, never study text or card content.
  if (choice?.finish_reason !== 'stop' || choice.message?.refusal) {
    console.log(JSON.stringify({ event: 'generation_rejected', label, finish: choice?.finish_reason ?? null,
      refusal: !!choice?.message?.refusal }));
    throw new APIError(502, 'invalid_response');
  }
  try { return { parsed: JSON.parse(choice.message.content) }; }
  catch { throw new APIError(502, 'invalid_response'); }
}

// Run async tasks with bounded concurrency (Workers cap simultaneous subrequests).
async function mapLimit(tasks, limit) {
  const results = new Array(tasks.length);
  let next = 0;
  const worker = async () => {
    while (next < tasks.length) {
      const i = next++;
      results[i] = await tasks[i]();
    }
  };
  await Promise.all(Array.from({ length: Math.min(limit, tasks.length) }, worker));
  return results;
}

// Flashcard generation. Topic mode (no document) is a single call. Document mode
// chunks the source and generates each section in parallel, ISOLATING failures: a
// bad/slow chunk drops only its own cards instead of killing the whole deck. The
// merged cards are then screened and deduped before the floor check.
export async function generateFlashcards(env, body) {
  const { language, difficulty } = body;
  const hasText = typeof body.text === 'string' && body.text.trim().length >= 50;
  if (!hasText) {
    const { parsed } = await callModel(env, openAIBody(body), 170_000, 'topic');
    const result = validateCards(parsed, body.count);
    console.log(JSON.stringify({ event: 'generation_parsed', mode: 'topic',
      count: Array.isArray(parsed?.cards) ? parsed.cards.length : -1, kept: result.cards.length }));
    return { ...result, coverage: { sections: 1, completed: 1 } };
  }
  const requested = Number.isInteger(body.count) ? body.count : 50;
  const chunks = chunkText(body.text, undefined, Math.min(8, requested));
  const budgets = chunks.map(() => 1);
  // Allocate a bounded card budget across every source section.
  for (let remaining = requested - chunks.length; remaining > 0; remaining--) {
    let best = 0;
    for (let i = 1; i < chunks.length; i++) {
      if (chunks[i].length / (budgets[i] + 1) > chunks[best].length / (budgets[best] + 1)) best = i;
    }
    budgets[best]++;
  }
  const tasks = chunks.map((chunk, index) => async () => {
    const perChunk = budgets[index];
    try {
      const { parsed } = await callModel(env, openAIChunkBody(chunk, { language, difficulty, count: perChunk, topic: body.topic }), 45_000, 'chunk');
      // Count a section as covered only when at least one usable card survives.
      const cards = Array.isArray(parsed?.cards) ? parsed.cards : [];
      return { cards };
    } catch (error) {
      return { cards: [], error: error instanceof APIError ? error : new APIError(503, 'service_unavailable') };
    }
  });
  const outcomes = await mapLimit(tasks, 4);
  // Interleave sections so a cap never keeps only the document's opening pages.
  const merged = [];
  const longest = Math.max(...outcomes.map(o => o.cards.length));
  for (let i = 0; i < longest; i++) for (const outcome of outcomes) {
    if (i < outcome.cards.length) merged.push(outcome.cards[i]);
  }
  if (merged.length === 0) {
    // Nothing came back: surface a real chunk error (502 truncation vs 503 outage)
    // rather than a misleading generic code.
    throw outcomes.find(o => o.error)?.error ?? new APIError(502, 'invalid_response');
  }
  const result = finalizeChunkedCards(merged, body.count);
  console.log(JSON.stringify({ event: 'generation_parsed', mode: 'chunked',
    chunks: chunks.length, raw: merged.length, kept: result.cards.length }));
  return { ...result, coverage: { sections: chunks.length,
    completed: outcomes.filter(o => o.cards.some(c => result.cards.some(kept => kept.regretPrompt === c?.regretPrompt))).length } };
}
