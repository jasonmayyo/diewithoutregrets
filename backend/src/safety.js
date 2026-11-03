import { APIError, readBody } from './protocol.js';

// Moderation is independent of the generation prompt. Nothing is displayed if
// screening is unavailable, malformed, or flags input/output. Never log text.
export async function requireSafeText(env, input, fetcher = fetch) {
  const strings = (Array.isArray(input) ? input : [input]).filter(value => typeof value === 'string' && value.trim());
  if (!strings.length) throw new APIError(503, 'safety_unavailable');
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 4_000);
  let stage = 'request';
  try {
    const response = await fetcher('https://api.openai.com/v1/moderations', {
      method: 'POST', signal: controller.signal, redirect: 'manual',
      headers: { authorization: `Bearer ${env.OPENAI_API_KEY}`, 'content-type': 'application/json' },
      body: JSON.stringify({ model: 'omni-moderation-latest', input: strings }),
    });
    if (!response.ok) {
      // Operational metadata only: never log study text, credentials or bodies.
      let cause = 'unspecified';
      let code = 'unspecified';
      let errorShape = 'unreadable';
      try {
        const { body } = await readBody(response, 8_000);
        errorShape = typeof body.error;
        const message = [body.error?.message, body.message, body.error?.detail, body.detail, body.error]
          .find(value => typeof value === 'string') || '';
        const providerCode = body.error?.code || body.code;
        if (['model_not_found', 'permission_denied', 'invalid_api_key', 'insufficient_quota',
          'rate_limit_exceeded', 'unsupported_country_region_territory'].includes(providerCode)) code = providerCode;
        if (/model/i.test(message) && /access|allow|permission|block|enable/i.test(message)) cause = 'model_access';
        else if (/permission|scope/i.test(message)) cause = 'missing_permission';
        else if (/country|region|territory/i.test(message)) cause = 'region';
        else if (/rate|too many|quota|limit/i.test(message)) cause = 'limit';
        else if (/forbidden|denied|blocked/i.test(message)) cause = 'access_denied';
      } catch { cause = 'unreadable_error'; }
      const requestID = response.headers.get('x-request-id');
      console.log(JSON.stringify({ event: 'moderation_unavailable', reason: 'upstream', status: response.status, cause, code, errorShape,
        providerRequestID: /^req[_-][a-zA-Z0-9_-]{1,80}$/.test(requestID || '') ? requestID : null }));
      stage = 'upstream_reported';
      await response.body?.cancel();
      throw new APIError(503, 'safety_unavailable');
    }
    stage = 'response_body';
    const { body } = await readBody(response, 128_000);
    stage = 'response_shape';
    if (!Array.isArray(body.results) || body.results.length !== strings.length ||
        body.results.some(result => typeof result?.flagged !== 'boolean' || !result.categories ||
          typeof result.categories !== 'object' || !Object.keys(result.categories).length ||
          Object.entries(result.categories).some(([category, value]) => typeof value !== 'boolean' &&
            !(value === null && ['illicit', 'illicit/violent'].includes(category))))) {
      throw new APIError(503, 'safety_unavailable');
    }
    if (body.results.some(result => result.flagged || Object.values(result.categories).some(Boolean))) {
      throw new APIError(422, 'unsafe_content');
    }
  } catch (error) {
    if (error?.code !== 'unsafe_content' && stage !== 'upstream_reported') {
      console.log(JSON.stringify({ event: 'moderation_unavailable', reason: controller.signal.aborted ? 'timeout' : stage }));
    }
    if (error instanceof APIError && ['unsafe_content', 'safety_unavailable'].includes(error.code)) throw error;
    throw new APIError(503, 'safety_unavailable');
  } finally { clearTimeout(timer); }
}

// Product-specific constraints stricter than moderation's general categories.
// This is a small additional check, never a replacement for provider screening.
export function requireRespectfulReply(text) {
  const normalized = text.normalize('NFKC').replace(/[’‘]/g, "'").replace(/\s+/g, ' ');
  if (/\b(?:you(?:'re| are) (?:worthless|useless|stupid|a failure)|you should give up|kill yourself|nobody (?:likes|loves) you)\b/i.test(normalized)) {
    throw new APIError(422, 'unsafe_content');
  }
}

export function responseText(result) {
  return Object.values(result).flatMap(value => Array.isArray(value) ? value : [value])
    .filter(value => typeof value === 'string');
}
