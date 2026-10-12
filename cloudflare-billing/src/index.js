/**
 * StokPilot receipt-verified subscription bridge for Firebase Spark.
 * RevenueCat validates App Store / Play purchases; this server verifies
 * RevenueCat's webhook secret and writes Pro only through an IAM account.
 * Never put the service account credential in Flutter or in GitHub.
 */
const PRODUCT = 'stokpilot_pro_monthly';
const PRO = 'pro';
const GOOGLE_TOKEN = 'https://oauth2.googleapis.com/token';
const MAX_BODY = 64000;

function send(message, status = 200) {
  return new Response(message, { status, headers: { 'content-type': 'text/plain; charset=utf-8' } });
}

function b64url(input) {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let binary = '';
  for (const char of bytes) binary += String.fromCharCode(char);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

async function oauthToken(serviceAccount) {
  if (!serviceAccount.client_email || !serviceAccount.private_key) {
    throw new Error('Service account missing client_email/private_key');
  }
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = b64url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: GOOGLE_TOKEN,
    iat: now, exp: now + 3600,
  }));
  const unsigned = `${head}.${payload}`;
  const pem = serviceAccount.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  const key = await crypto.subtle.importKey(
    'pkcs8', Uint8Array.from(atob(pem), c => c.charCodeAt(0)),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  );
  const signed = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const jwt = `${unsigned}.${b64url(new Uint8Array(signed))}`;
  const result = await fetch(GOOGLE_TOKEN, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt,
    }),
  });
  if (!result.ok) throw new Error(`Google OAuth failed: ${result.status}`);
  const body = await result.json();
  return body.access_token;
}

function docUrl(project, id) {
  return `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(project)}` +
    `/databases/(default)/documents/workspaces/${encodeURIComponent(id)}`;
}
async function firestoreGet(url, token) {
  const res = await fetch(url, { headers: { authorization: `Bearer ${token}` } });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`Firestore read failed: ${res.status}`);
  return res.json();
}

// Returns a verified entitlement state or null for non-entitlement changes.
export function determineEntitlement(event, now = Date.now()) {
  if (typeof event !== 'object' || event === null) return null;
  const id = event.product_id;
  if (typeof id !== 'string' || (id !== PRODUCT && !id.startsWith(`${PRODUCT}:`))) return null;
  const timestamp = event.event_timestamp_ms;
  if (!Number.isSafeInteger(timestamp) || timestamp < 0) return null;
  const activeTypes = new Set(['INITIAL_PURCHASE', 'RENEWAL', 'UNCANCELLATION', 'PRODUCT_CHANGE', 'SUBSCRIPTION_EXTENDED']);
  if (activeTypes.has(event.type)) {
    if (!Array.isArray(event.entitlement_ids) || !event.entitlement_ids.includes(PRO)) return null;
    if (!Number.isSafeInteger(event.expiration_at_ms) || event.expiration_at_ms <= now) return null;
    return { status: 'active', expiresMs: event.expiration_at_ms, atMs: timestamp };
  }
  if (event.type === 'EXPIRATION') {
    return { status: 'expired', expiresMs: 0, atMs: timestamp };
  }
  // Cancellation of auto-renewal alone does not terminate a paid period.
  // Refunds should normally send a subsequent expiration event.
  return null;
}

async function writeEntitlement(baseUrl, token, event, state) {
  const ref = `${baseUrl}/entitlements/current`;
  // Optimistic concurrency protects from delayed/duplicated notifications.
  for (let retry = 0; retry < 4; retry++) {
    const current = await firestoreGet(ref, token);
    const fields = current?.fields ?? {};
    const previousTime = Number(fields.eventAtMs?.integerValue ?? -1);
    if (previousTime > state.atMs ||
        (previousTime === state.atMs && fields.lastEventId?.stringValue === event.id)) return;
    const url = new URL(ref);
    if (current) url.searchParams.set('currentDocument.updateTime', current.updateTime);
    else url.searchParams.set('currentDocument.exists', 'false');
    const updated = {
      fields: {
        status: { stringValue: state.status },
        source: { stringValue: 'revenuecat' },
        expiresAt: { timestampValue: new Date(state.expiresMs).toISOString() },
        productId: { stringValue: event.product_id },
        eventAtMs: { integerValue: String(state.atMs) },
        lastEventId: { stringValue: event.id },
        updatedAt: { timestampValue: new Date().toISOString() },
      },
    };
    const res = await fetch(url, {
      method: 'PATCH',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify(updated),
    });
    if (res.ok) return;
    if (res.status === 409 || res.status === 412) continue;
    throw new Error(`Firestore entitlement update failed: ${res.status}`);
  }
  throw new Error('Concurrent Firestore subscription event updates, retry later');
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/health' && request.method === 'GET') return send('ok');
    if (url.pathname !== '/revenuecat') return send('not found', 404);
    if (request.method !== 'POST') return send('method not allowed', 405);
    if (!env.REVENUECAT_WEBHOOK_SECRET ||
      request.headers.get('authorization') !== `Bearer ${env.REVENUECAT_WEBHOOK_SECRET}`) {
      return send('unauthorized', 401);
    }
    if (Number(request.headers.get('content-length') ?? 0) > MAX_BODY) return send('too large', 413);
    let body;
    try {
      const raw = await request.text();
      if (raw.length > MAX_BODY) return send('too large', 413);
      body = JSON.parse(raw);
    } catch (_) { return send('invalid json', 400); }
    const event = body?.event;
    if (!event || typeof event.id !== 'string' || event.id.length > 256 ||
      typeof event.app_user_id !== 'string') return send('invalid event', 400);
    const uid = event.app_user_id;
    if (!/^[A-Za-z0-9_-]{1,128}$/.test(uid) || uid.startsWith('$RCAnonymousID')) return send('ignored');
    const state = determineEntitlement(event);
    if (!state) return send('ignored');
    try {
      const credentials = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
      if (credentials.project_id !== env.FIREBASE_PROJECT_ID) {
        throw new Error('Firebase project and service account mismatch');
      }
      const token = await oauthToken(credentials);
      const root = docUrl(env.FIREBASE_PROJECT_ID, uid);
      const workspace = await firestoreGet(root, token);
      if (!workspace) return send('ignored workspace missing');
      await writeEntitlement(root, token, event, state);
      return send('ok');
    } catch (error) {
      // Avoid logging secret or PII. Non-200 lets RevenueCat retry.
      console.error('RevenueCat webhook processing failed:', error?.message ?? 'unknown');
      return send('try again', 503);
    }
  },
};
