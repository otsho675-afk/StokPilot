import { appleRootCAs } from './apple-roots.js';

/**
 * Direct Apple App Store Server API / Google Play Developer API billing.
 * No RevenueCat. All privileged credentials stay in Worker secrets.
 * Entitlements are granted only after store verification + Firebase ID token verification.
 */
const PRODUCT = 'stokpilot_pro_monthly';
const MAX_BODY = 8192;
const GOOGLE_TOKEN = 'https://oauth2.googleapis.com/token';
const JWK_URL = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const scopes = 'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/androidpublisher';
const MINUTE = 60000;

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });
}
function encode(input) {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let str = '';
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}
function decode(str) {
  const base64 = str.replace(/-/g, '+').replace(/_/g, '/');
  return Uint8Array.from(atob(base64.padEnd(Math.ceil(base64.length / 4) * 4, '=')), x => x.charCodeAt(0));
}
function privateKey(pem, alg) {
  const body = pem.replace(/-----BEGIN [^-]+-----|-----END [^-]+-----|\s/g, '');
  const format = alg === 'RS256' ? { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }
    : { name: 'ECDSA', namedCurve: 'P-256' };
  return crypto.subtle.importKey('pkcs8', decode(body), format, false, ['sign']);
}
async function signJwt(header, body, pem, alg) {
  const unsigned = encode(JSON.stringify(header)) + '.' + encode(JSON.stringify(body));
  const key = await privateKey(pem, alg);
  const signature = await crypto.subtle.sign(
    alg === 'RS256' ? 'RSASSA-PKCS1-v1_5' : { name: 'ECDSA', hash: 'SHA-256' },
    key, new TextEncoder().encode(unsigned),
  );
  return unsigned + '.' + encode(new Uint8Array(signature));
}
async function googleAccessToken(sa) {
  if (!sa?.client_email || !sa?.private_key) throw new Error('Service account unconfigured');
  const iat = Math.floor(Date.now() / 1000);
  const jwt = await signJwt({ typ: 'JWT', alg: 'RS256' }, {
    iss: sa.client_email, scope: scopes, aud: GOOGLE_TOKEN, iat, exp: iat + 3600,
  }, sa.private_key, 'RS256');
  const res = await fetch(GOOGLE_TOKEN, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt }),
  });
  if (!res.ok) throw new Error('Google service authentication failed: ' + res.status);
  return (await res.json()).access_token;
}
export async function verifyFirebaseIdToken(token, project) {
  if (!token || token.length > 10000) throw new Error('Invalid Firebase token');
  const [headerSegment, payloadSegment, signatureSegment] = token.split('.');
  const header = JSON.parse(new TextDecoder().decode(decode(headerSegment)));
  const payload = JSON.parse(new TextDecoder().decode(decode(payloadSegment)));
  const now = Math.floor(Date.now() / 1000);
  if (header.alg !== 'RS256' || !header.kid ||
    payload.aud !== project || payload.iss !== 'https://securetoken.google.com/' + project ||
    !payload.sub || !/^[\w-]{1,128}$/.test(payload.sub) ||
    !Number.isInteger(payload.exp) || payload.exp <= now ||
    !Number.isInteger(payload.iat) || payload.iat > now + 60 ||
    !Number.isInteger(payload.auth_time) || payload.auth_time > now + 60) {
    throw new Error('Firebase token claims rejected');
  }
  const res = await fetch(JWK_URL);
  if (!res.ok) throw new Error('Firebase signing keys unavailable');
  const jwks = await res.json();
  const jwk = jwks.keys?.find(x => x.kid === header.kid && x.kty === 'RSA');
  if (!jwk) throw new Error('Unknown Firebase signing key');
  const key = await crypto.subtle.importKey('jwk', jwk, {
    name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256',
  }, false, ['verify']);
  const valid = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key,
    decode(signatureSegment), new TextEncoder().encode(headerSegment + '.' + payloadSegment));
  if (!valid) throw new Error('Firebase signature invalid');
  return payload.sub;
}
function storeConfig(env) {
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON || !env.FIREBASE_PROJECT_ID ||
      !env.APPLE_BUNDLE_ID || !env.GOOGLE_PACKAGE_NAME) throw new Error('Store secrets/config missing');
  const sa = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
  if (sa.project_id !== env.FIREBASE_PROJECT_ID) throw new Error('Wrong Firebase service account');
  return sa;
}
function baseUrl(project) {
  return 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(project) +
    '/databases/(default)/documents';
}
function doc(base, uid) { return base + '/workspaces/' + encodeURIComponent(uid) + '/entitlements/current'; }
async function readDoc(url, access) {
  const response = await fetch(url, { headers: { authorization: 'Bearer ' + access } });
  if (response.status === 404) return null;
  if (!response.ok) throw new Error('Firestore read failed: ' + response.status);
  return response.json();
}
function sf(value) { return { stringValue: value }; }
function tf(ms) { return { timestampValue: new Date(ms).toISOString() }; }
function asString(fields, name) { return fields?.[name]?.stringValue ?? ''; }
function asMillis(fields, name) { return Date.parse(fields?.[name]?.timestampValue ?? '') || 0; }
async function bindingKey(platform, reference) {
  const bytes = new TextEncoder().encode(platform + ':' + reference);
  return platform + '_' + Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)),
    x => x.toString(16).padStart(2, '0')).join('');
}
async function appleAuth(env) {
  if (!env.APPLE_ISSUER_ID || !env.APPLE_KEY_ID || !env.APPLE_PRIVATE_KEY) {
    throw new Error('Apple subscription verification is not configured');
  }
  const now = Math.floor(Date.now() / 1000);
  return signJwt({ alg: 'ES256', kid: env.APPLE_KEY_ID, typ: 'JWT' }, {
    iss: env.APPLE_ISSUER_ID, iat: now, exp: now + 900,
    aud: 'appstoreconnect-v1', bid: env.APPLE_BUNDLE_ID,
  }, env.APPLE_PRIVATE_KEY.replace(/\\n/g, '\n'), 'ES256');
}
function appleTransaction(t, bundle) {
  if (t.bundleId !== bundle || t.productId !== PRODUCT ||
    !/^\d+$/.test(String(t.originalTransactionId ?? ''))) {
    throw new Error('Apple subscription does not belong to this app/product');
  }
  return t;
}
export async function appleState(response, bundle, verifier, original = null, now = Date.now(), appId = null) {
  const items = (response.data ?? []).flatMap(x => x.lastTransactions ?? []);
  const candidates = await Promise.all(items.map(async item => {
    // Apple's API is authenticated, but its embedded JWS still needs signature,
    // certificate-chain, app and environment verification before granting access.
    const tx = appleTransaction(await verifier.verifyAndDecodeTransaction(item.signedTransactionInfo), bundle);
    if (appId !== null && Number(tx.appAppleId) !== appId) {
      throw new Error('Apple app ID mismatch');
    }
    if (original && String(tx.originalTransactionId) !== String(original)) return null;
    let ms = Number(tx.expiresDate ?? 0);
    // 1 = active, 4 = billing grace period. Revoked transactions never grant Pro.
    const allowed = [1, 4].includes(Number(item.status)) && !tx.revocationDate;
    if (Number(item.status) === 4 && allowed) {
      if (!item.signedRenewalInfo) throw new Error('Apple grace period renewal proof missing');
      const renewal = await verifier.verifyAndDecodeRenewalInfo(item.signedRenewalInfo);
      if (String(renewal.originalTransactionId) !== String(tx.originalTransactionId)) {
        throw new Error('Apple renewal transaction mismatch');
      }
      ms = Number(renewal.gracePeriodExpiresDate ?? 0);
    }
    return { lookup: String(tx.originalTransactionId), expiresMs: allowed ? ms : 0,
      environment: tx.environment, productId: tx.productId };
  }));
  const validCandidates = candidates.filter(Boolean);
  if (!validCandidates.length) throw new Error('Apple subscription not found');
  validCandidates.sort((a, b) => b.expiresMs - a.expiresMs);
  const state = validCandidates[0];
  return { ...state, expiresMs: state.expiresMs > now ? state.expiresMs : 0 };
}
async function appleStatus(transactionId, env, original = null) {
  if (!/^\d{4,32}$/.test(transactionId)) throw new Error('Invalid Apple transaction ID');
  // jsrsasign initializes random state at module load, which Workers disallows
  // in global scope. Load Apple's verifier only while handling a request.
  const { Environment, SignedDataVerifier } = await import('@apple/app-store-server-library');
  const jwt = await appleAuth(env);
  const appId = Number(env.APPLE_APP_ID);
  if (!Number.isSafeInteger(appId) || appId <= 0) throw new Error('Apple app ID is not configured');
  for (const [host, environment] of [
    ['https://api.storekit.apple.com', Environment.PRODUCTION],
    ['https://api.storekit-sandbox.apple.com', Environment.SANDBOX],
  ]) {
    const response = await fetch(host + '/inApps/v1/subscriptions/' + encodeURIComponent(transactionId), {
      headers: { authorization: 'Bearer ' + jwt },
    });
    if (response.status === 404) continue;
    if (!response.ok) throw new Error('Apple verification error: ' + response.status);
    const verifier = new SignedDataVerifier(appleRootCAs, true, environment, env.APPLE_BUNDLE_ID,
      environment === Environment.PRODUCTION ? appId : undefined);
    return appleState(await response.json(), env.APPLE_BUNDLE_ID, verifier, original,
      Date.now(), environment === Environment.PRODUCTION ? appId : null);
  }
  throw new Error('Apple transaction not found');
}
export function playState(data, now = Date.now()) {
  const lines = (data?.lineItems ?? []).filter(x => x.productId === PRODUCT);
  if (!lines.length) throw new Error('Google Play product mismatch');
  const permitted = ['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
    'SUBSCRIPTION_STATE_CANCELED'].includes(data.subscriptionState);
  const expiry = Math.max(...lines.map(x => Date.parse(x.expiryTime ?? '') || 0));
  return { expiresMs: permitted && expiry > now ? expiry : 0, productId: PRODUCT,
    linkedPurchaseToken: data.linkedPurchaseToken ?? null };
}
async function playStatus(purchaseToken, env, access) {
  if (typeof purchaseToken !== 'string' || purchaseToken.length < 8 || purchaseToken.length > 4096) {
    throw new Error('Invalid Google Play purchase token');
  }
  const endpoint = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' +
    encodeURIComponent(env.GOOGLE_PACKAGE_NAME) + '/purchases/subscriptionsv2/tokens/' +
    encodeURIComponent(purchaseToken);
  const response = await fetch(endpoint, { headers: { authorization: 'Bearer ' + access } });
  if (!response.ok) throw new Error('Google Play verification error: ' + response.status);
  return { ...playState(await response.json()), lookup: purchaseToken };
}
async function verifyStore(platform, lookup, env, access, original = null) {
  if (platform === 'ios') return appleStatus(lookup, env, original);
  if (platform === 'android') return playStatus(lookup, env, access);
  throw new Error('Unsupported platform');
}
function precondition(existing) {
  return existing ? { updateTime: existing.updateTime } : { exists: false };
}
async function persist(env, access, uid, platform, storeState) {
  const base = baseUrl(env.FIREBASE_PROJECT_ID);
  const bkey = await bindingKey(platform, storeState.lookup);
  const bpath = base + '/billingPurchases/' + bkey;
  const linkedKey = platform === 'android' && storeState.linkedPurchaseToken
    ? await bindingKey('android', storeState.linkedPurchaseToken) : null;
  const epath = doc(base, uid);
  for (let retry = 0; retry < 4; retry++) {
    const [workspace, binding, entitlement] = await Promise.all([
      readDoc(base + '/workspaces/' + encodeURIComponent(uid), access),
      readDoc(bpath, access), readDoc(epath, access),
    ]);
    if (!workspace || workspace.fields?.deletedAt) throw new Error('Workspace not available');
    if (linkedKey && linkedKey !== bkey) {
      const previousPurchase = await readDoc(base + '/billingPurchases/' + linkedKey, access);
      if (previousPurchase && asString(previousPurchase.fields, 'uid') !== uid) {
        return { error: 'Subscription is linked to a different account', status: 409 };
      }
    }
    if (binding && asString(binding.fields, 'uid') !== uid) {
      return { error: 'This store subscription is already linked to a different account', status: 409 };
    }
    const now = Date.now();
    const previousExpiry = asMillis(entitlement?.fields, 'expiresAt');
    const previousKey = asString(entitlement?.fields, 'purchaseKey');
    let expiresMs = storeState.expiresMs;
    let bestKey = bkey;
    let bestProvider = platform;
    // Never disable a second, still-active store purchase from a different platform.
    if (previousKey && previousKey !== bkey && previousExpiry > expiresMs && previousExpiry > now) {
      expiresMs = previousExpiry;
      bestKey = previousKey;
      bestProvider = asString(entitlement.fields, 'provider') || platform;
    }
    const bindingFields = {
      uid: sf(uid), provider: sf(platform), lookup: sf(storeState.lookup),
      productId: sf(PRODUCT), expiresAt: tf(storeState.expiresMs || 0),
      nextCheckAt: tf(now + 60 * MINUTE),
      updatedAt: tf(now),
    };
    const entitlementFields = {
      status: sf(expiresMs > now ? 'active' : 'expired'),
      source: sf('direct-store'), expiresAt: tf(expiresMs || 0),
      productId: sf(PRODUCT), provider: sf(bestProvider), purchaseKey: sf(bestKey),
      updatedAt: tf(now),
    };
    const writes = [
      { update: { name: bpath, fields: bindingFields }, currentDocument: precondition(binding) },
      { update: { name: epath, fields: entitlementFields }, currentDocument: precondition(entitlement) },
    ];
    const response = await fetch(base + ':commit', {
      method: 'POST',
      headers: { authorization: 'Bearer ' + access, 'content-type': 'application/json' },
      body: JSON.stringify({ writes }),
    });
    if (response.ok) return { status: 200, active: expiresMs > now, expiresAt: new Date(expiresMs).toISOString() };
    if (response.status === 409 || response.status === 412) continue;
    throw new Error('Firestore commit failed: ' + response.status);
  }
  throw new Error('Concurrent subscription updates; retry');
}
async function readDue(env, access, cutoff, after = null) {
  const base = baseUrl(env.FIREBASE_PROJECT_ID);
  const structuredQuery = {
    from: [{ collectionId: 'billingPurchases' }],
    where: { fieldFilter: {
      field: { fieldPath: 'nextCheckAt' }, op: 'LESS_THAN_OR_EQUAL', value: cutoff,
    } },
    orderBy: [
      { field: { fieldPath: 'nextCheckAt' }, direction: 'ASCENDING' },
      { field: { fieldPath: '__name__' }, direction: 'ASCENDING' },
    ],
    limit: 25,
  };
  if (after) structuredQuery.startAt = { values: [after.fields.nextCheckAt,
    { referenceValue: after.name }], before: false };
  const response = await fetch(base + ':runQuery', {
    method: 'POST',
    headers: { authorization: 'Bearer ' + access, 'content-type': 'application/json' },
    body: JSON.stringify({ structuredQuery }),
  });
  if (!response.ok) throw new Error('Firestore scheduled query failed: ' + response.status);
  return (await response.json()).map(x => x.document).filter(Boolean);
}
export default {
  async fetch(request, env) {
    const path = new URL(request.url).pathname;
    if (path === '/health' && request.method === 'GET') return json({ ok: true, provider: 'direct-store' });
    if (path !== '/verify' || request.method !== 'POST') return json({ error: 'not found' }, 404);
    if (Number(request.headers.get('content-length') || 0) > MAX_BODY) return json({ error: 'payload too large' }, 413);
    let body;
    try {
      const raw = await request.text();
      if (raw.length > MAX_BODY) return json({ error: 'payload too large' }, 413);
      body = JSON.parse(raw);
      if (!['ios', 'android'].includes(body.platform) || body.productId !== PRODUCT) {
        return json({ error: 'Invalid product or platform' }, 400);
      }
      const reference = body.platform === 'ios' ? body.transactionId : body.purchaseToken;
      if (typeof reference !== 'string' || !reference) return json({ error: 'Missing store proof' }, 400);
      const token = /^Bearer (.+)$/.exec(request.headers.get('authorization') ?? '')?.[1];
      const uid = await verifyFirebaseIdToken(token, env.FIREBASE_PROJECT_ID);
      const sa = storeConfig(env);
      const access = await googleAccessToken(sa);
      const state = await verifyStore(body.platform, reference, env, access);
      // Binding protects against reusing a store purchase across Firebase users.
      const result = await persist(env, access, uid, body.platform, state);
      return json(result.error ? { error: result.error } : result, result.status);
    } catch (e) {
      const message = e?.message ?? 'Unknown verification error';
      if (/token|signature|claims/i.test(message)) return json({ error: 'Authentication failed' }, 401);
      console.error('Billing verification failed:', message);
      return json({ error: 'Store verification unavailable; try again later' }, 503);
    }
  },
  async scheduled(_event, env, ctx) {
    ctx.waitUntil((async () => {
      const sa = storeConfig(env);
      const access = await googleAccessToken(sa);
      const cutoff = tf(Date.now());
      let after = null;
      for (let page = 0; page < 20; page++) {
        const due = await readDue(env, access, cutoff, after);
        if (!due.length) break;
        after = due[due.length - 1];
        for (const record of due) {
          try {
            const fields = record.fields ?? {};
            const uid = asString(fields, 'uid');
            const provider = asString(fields, 'provider');
            const lookup = asString(fields, 'lookup');
            if (!uid || !lookup || !['ios', 'android'].includes(provider)) continue;
            const storeState = await verifyStore(provider, lookup, env, access,
              provider === 'ios' ? lookup : null);
            await persist(env, access, uid, provider, storeState);
          } catch (e) {
            console.error('Scheduled purchase check failed:', e?.message ?? 'unknown');
          }
        }
        if (due.length < 25) break;
      }
    })());
  },
};
