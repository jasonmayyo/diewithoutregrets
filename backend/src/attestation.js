import { verifyAttestation, verifyAssertion } from 'node-app-attest';
import { X509Certificate } from 'node:crypto';
import cbor from 'cbor';

export function attest(attestation, challenge, keyId, env) {
  // The verifier checks the pinned Apple chain, nonce, app identity, key ID,
  // zero counter and production AAGUID. Also enforce certificate validity dates.
  const decoded = cbor.decodeAllSync(attestation);
  if (decoded.length !== 1 || decoded[0]?.attStmt?.x5c?.length !== 2) throw new Error('invalid attestation');
  for (const certData of decoded[0].attStmt.x5c) {
    const cert = new X509Certificate(certData);
    const now = Date.now();
    if (now < Date.parse(cert.validFrom) || now > Date.parse(cert.validTo)) throw new Error('expired certificate');
  }
  return verifyAttestation({ attestation, challenge, keyId,
    bundleIdentifier: env.BUNDLE_ID, teamIdentifier: env.APP_ID_PREFIX,
    allowDevelopmentEnvironment: env.ALLOW_DEVELOPMENT_ATTESTATION === 'true' });
}

export function assertRequest(assertion, raw, key, env) {
  const objects = cbor.decodeAllSync(assertion);
  if (objects.length !== 1 || !Buffer.isBuffer(objects[0]?.authenticatorData) ||
      objects[0].authenticatorData.length < 37 || !Buffer.isBuffer(objects[0]?.signature)) throw new Error('invalid assertion');
  return verifyAssertion({ assertion, payload: raw, publicKey: key.public_key,
    signCount: key.counter, bundleIdentifier: env.BUNDLE_ID, teamIdentifier: env.APP_ID_PREFIX });
}
