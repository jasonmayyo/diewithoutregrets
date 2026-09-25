import { DurableObject } from 'cloudflare:workers';
import { createHash, randomBytes } from 'node:crypto';
import { APIError, json, readBody, validKeyID, validateGeneration, openAIBody, validateCards } from './protocol.js';
import { GateStore, generationLimits } from './store.js';
import { attest, assertRequest } from './attestation.js';

const paths = new Set(['/v1/challenge', '/v1/attest', '/v1/flashcards']);

export default {
  async fetch(request, env) {
    const path = new URL(request.url).pathname;
    if (path === '/health' && request.method === 'GET') return json({ service: 'studyguard-ai', enabled: env.AI_ENABLED === 'true' && !!env.OPENAI_API_KEY });
    if (request.method !== 'POST' || !paths.has(path)) return json({ error: { code: 'not_found' } }, 404);
    // One global coordinator provides atomic installation + service-wide limits.
    // A promoted development Worker must not trust keys enrolled in its old
    // sandbox ledger. Keep production and development registrations separate.
    const ledger = env.ALLOW_DEVELOPMENT_ATTESTATION === 'true'
      ? 'studyguard-development-v1' : 'studyguard-production-v1';
    return env.GATE.get(env.GATE.idFromName(ledger)).fetch(request);
  },
};

export class StudyGuardGate extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.env = env;
    this.store = new GateStore(ctx.storage);
  }
  async fetch(request) {
    try { return await this.handle(request); }
    catch (error) {
      // Do not log documents, assertions, provider responses, or credentials.
      const status = error instanceof APIError ? error.status : 503;
      const code = error instanceof APIError ? error.code : 'service_unavailable';
      return json({ error: { code } }, status, status === 429 ? { 'Retry-After': '60' } : {});
    }
  }
  async handle(request) {
    const path = new URL(request.url).pathname;
    const now = Date.now();
    this.store.cleanup(now);
    if (!this.env.BUNDLE_ID || !this.env.APP_ID_PREFIX) throw new APIError(503, 'service_unavailable');
    const ipBucket = createHash('sha256').update(`${Math.floor(now / 86_400_000)}:${request.headers.get('CF-Connecting-IP') || 'local'}`).digest('hex');
    const minute = Math.floor(now / 60_000);
    this.store.consumeLimits([
      { bucket: `ip:${ipBucket}:${minute}`, limit: 60, expires: (minute + 1) * 60_000, code: 'rate_limited' },
      { bucket: `traffic:${minute}`, limit: 1000, expires: (minute + 1) * 60_000, code: 'service_busy' },
    ], now);
    const { raw, body } = await readBody(request, path === '/v1/flashcards' ? 650_000 : 32_768);
    if (path === '/v1/challenge') {
      const keyID = validKeyID(body.keyId);
      const purpose = this.store.key(keyID) ? 'generate' : 'attest';
      const challenge = randomBytes(32).toString('base64url');
      this.store.challenge(challenge, keyID, purpose, Date.now());
      return json({ challenge, purpose, expiresIn: 300 });
    }
    if (path === '/v1/attest') {
      const keyID = validKeyID(body.keyId);
      if (typeof body.attestation !== 'string' || body.attestation.length > 24_000) throw new APIError(400, 'invalid_request');
      this.store.takeChallenge(body.challenge, keyID, 'attest', Date.now());
      let result;
      try { result = attest(Buffer.from(body.attestation, 'base64'), body.challenge, keyID, this.env); }
      catch { throw new APIError(401, 'attestation_failed'); }
      this.store.addKey(keyID, result.publicKey);
      return json({ registered: true });
    }
    if (path !== '/v1/flashcards') throw new APIError(404, 'not_found');
    if (this.env.AI_ENABLED !== 'true' || !this.env.OPENAI_API_KEY) throw new APIError(503, 'service_unavailable');
    validateGeneration(body);
    const keyID = validKeyID(request.headers.get('X-App-Attest-Key-ID'));
    const key = this.store.key(keyID);
    if (!key) throw new APIError(401, 'key_not_registered');
    const assertion = request.headers.get('X-App-Attest-Assertion');
    if (!assertion || assertion.length > 4096) throw new APIError(401, 'invalid_assertion');
    this.store.takeChallenge(body.challenge, keyID, 'generate', Date.now());
    let result;
    try { result = assertRequest(Buffer.from(assertion, 'base64'), raw, key, this.env); }
    catch { throw new APIError(401, 'invalid_assertion'); }
    this.store.advanceCounter(keyID, key.counter, result.signCount);
    const reservedAt = Date.now();
    this.store.reserve(keyID, body.requestId, generationLimits(this.env, keyID, reservedAt), reservedAt);
    try {
      // No automatic retries: a timeout may still have incurred provider usage.
      const upstream = await fetch('https://api.openai.com/v1/chat/completions', {
        // Workers supports manual redirects; reject any 3xx below without
        // forwarding the provider credential or study text to another host.
        method: 'POST', redirect: 'manual', signal: AbortSignal.timeout(170_000),
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${this.env.OPENAI_API_KEY}` },
        body: JSON.stringify(openAIBody(body.text, body.language)),
      });
      if (!upstream.ok) { await upstream.body?.cancel(); throw new APIError(503, 'service_unavailable'); }
      const { body: response } = await readBody(upstream, 300_000);
      const choice = response.choices?.[0];
      // Diagnostics only: counts and reasons, never study text or card content.
      if (choice?.finish_reason !== 'stop' || choice.message?.refusal) {
        console.log(JSON.stringify({ event: 'generation_rejected', finish: choice?.finish_reason ?? null,
          refusal: !!choice?.message?.refusal, usage: response.usage ?? null }));
        throw new APIError(502, 'invalid_response');
      }
      let cards;
      try { cards = JSON.parse(choice.message.content); } catch { throw new APIError(502, 'invalid_response'); }
      console.log(JSON.stringify({ event: 'generation_parsed', count: Array.isArray(cards?.cards) ? cards.cards.length : -1,
        usage: response.usage ?? null }));
      return json(validateCards(cards));
    } catch (error) {
      if (error instanceof APIError) throw error;
      throw new APIError(503, 'service_unavailable');
    } finally {
      // Reservations remain counted on failure; uncertain/failed paid work cannot
      // evade the circuit breaker by deliberately disconnecting or causing errors.
      this.store.finish(keyID, body.requestId);
    }
  }
}
