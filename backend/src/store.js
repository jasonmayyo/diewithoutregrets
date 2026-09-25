import { APIError } from './protocol.js';

// A single SQLite-backed Durable Object owns this ledger. Transactions reserve
// every limit BEFORE any paid call; concurrent requests cannot read stale counts.
export class GateStore {
  constructor(storage) {
    this.storage = storage;
    this.sql = storage.sql;
    this.sql.exec('CREATE TABLE IF NOT EXISTS keys (id TEXT PRIMARY KEY, public_key TEXT NOT NULL, counter INTEGER NOT NULL)');
    this.sql.exec('CREATE TABLE IF NOT EXISTS challenges (id TEXT PRIMARY KEY, key_id TEXT NOT NULL, purpose TEXT NOT NULL, expires INTEGER NOT NULL)');
    this.sql.exec('CREATE TABLE IF NOT EXISTS counters (bucket TEXT PRIMARY KEY, count INTEGER NOT NULL, expires INTEGER NOT NULL)');
    this.sql.exec('CREATE TABLE IF NOT EXISTS inflight (key_id TEXT PRIMARY KEY, request_id TEXT NOT NULL, expires INTEGER NOT NULL)');
  }
  one(query, ...params) { return [...this.sql.exec(query, ...params)][0]; }
  cleanup(now) {
    for (const table of ['challenges', 'counters', 'inflight']) this.sql.exec(`DELETE FROM ${table} WHERE expires <= ?`, now);
  }
  consumeLimits(limits, now) {
    this.storage.transactionSync(() => this.incrementLimits(limits, now));
  }
  incrementLimits(limits, now) {
      for (const { bucket, limit, expires, code } of limits) {
        const count = this.one('SELECT count FROM counters WHERE bucket = ? AND expires > ?', bucket, now)?.count || 0;
        if (count >= limit) throw new APIError(429, code);
        this.sql.exec('INSERT INTO counters VALUES (?, ?, ?) ON CONFLICT(bucket) DO UPDATE SET count=excluded.count, expires=excluded.expires', bucket, count + 1, expires);
      }
  }
  key(id) { return this.one('SELECT * FROM keys WHERE id = ?', id); }
  addKey(id, publicKey) {
    // Never reset an existing assertion counter or replace an attested public key.
    this.sql.exec('INSERT INTO keys VALUES (?, ?, 0) ON CONFLICT(id) DO NOTHING', id, publicKey);
  }
  challenge(id, keyID, purpose, now) {
    this.sql.exec('INSERT INTO challenges VALUES (?, ?, ?, ?)', id, keyID, purpose, now + 300_000);
  }
  takeChallenge(id, keyID, purpose, now) {
    if (typeof id !== 'string' || id.length > 100) throw new APIError(401, 'invalid_challenge');
    this.storage.transactionSync(() => {
      const row = this.one('SELECT * FROM challenges WHERE id = ?', id);
      if (!row || row.expires <= now || row.key_id !== keyID || row.purpose !== purpose) throw new APIError(401, 'invalid_challenge');
      this.sql.exec('DELETE FROM challenges WHERE id = ?', id);
    });
  }
  advanceCounter(keyID, oldCount, newCount) {
    this.storage.transactionSync(() => {
      if (!Number.isSafeInteger(newCount) || newCount <= oldCount || this.key(keyID)?.counter !== oldCount) {
        throw new APIError(401, 'invalid_assertion');
      }
      this.sql.exec('UPDATE keys SET counter = ? WHERE id = ?', newCount, keyID);
    });
  }
  reserve(keyID, requestID, limits, now) {
    this.storage.transactionSync(() => {
      if (this.one('SELECT key_id FROM inflight WHERE key_id = ? AND expires > ?', keyID, now)) throw new APIError(429, 'generation_in_progress');
      if (this.one('SELECT COUNT(*) AS count FROM inflight WHERE expires > ?', now).count >= 8) throw new APIError(429, 'service_busy');
      this.incrementLimits(limits, now);
      this.sql.exec('INSERT INTO inflight VALUES (?, ?, ?) ON CONFLICT(key_id) DO UPDATE SET request_id=excluded.request_id, expires=excluded.expires', keyID, requestID, now + 240_000);
    });
  }
  finish(keyID, requestID) { this.sql.exec('DELETE FROM inflight WHERE key_id = ? AND request_id = ?', keyID, requestID); }
}

export function generationLimits(env, keyID, now) {
  const date = new Date(now);
  const day = date.toISOString().slice(0, 10);
  const month = day.slice(0, 7);
  const midnight = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() + 1);
  const nextMonth = Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 1);
  const limit = name => {
    const n = Number(env[name]);
    if (!Number.isSafeInteger(n) || n < 1 || n > 100_000) throw new APIError(503, 'service_unavailable');
    return n;
  };
  return [
    { bucket: `minute:${keyID}:${Math.floor(now / 60_000)}`, limit: 3, expires: (Math.floor(now / 60_000) + 1) * 60_000, code: 'rate_limited' },
    { bucket: `device:${keyID}:${day}`, limit: limit('DEVICE_DAILY_LIMIT'), expires: midnight, code: 'daily_limit' },
    { bucket: `global:${day}`, limit: limit('GLOBAL_DAILY_LIMIT'), expires: midnight, code: 'service_limit' },
    { bucket: `global:${month}`, limit: limit('GLOBAL_MONTHLY_LIMIT'), expires: nextMonth, code: 'service_limit' },
  ];
}
