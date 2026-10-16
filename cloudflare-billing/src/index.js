/**
 * Native App Store / Google Play subscription verifier.
 *
 * POST /verify {platform: 'ios'|'android', proof, productId}
 * Authorization: Bearer <Firebase ID token>
 *
 * Proof is NEVER enough to grant Pro: transaction/subscription status is
 * fetched directly from Apple/Google with server-held credentials.
 * Firestore claims bind each original purchase to one Firebase user.
 */
const PRODUCT = 'stokpilot_pro_monthly';
const GOOGLE_TOKEN = 'https://oauth2.googleapis.com/token';
const FIREBASE_JWKS = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const MAX_BODY = 8192;

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status, headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });
}
function b64url(data) {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data;
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}
function unbase64url(value) {
  const padded = value.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(value.length / 4) * 4, '=');
  return Uint8Array.from(atob(padded), c => c.charCodeAt(0));
}
function jwtBody(jwt) {
  if (typeof jwt !== 'string' || jwt.split('.').length !== 3) throw Error('invalid JWT');
  return JSON.parse(new TextDecoder().decode(unbase64url(jwt.split('.')[1])));
}
async function rsaPrivateKey(pem) {
  const raw = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  return crypto.subtle.importKey('pkcs8', Uint8Array.from(atob(raw), c => c.charCodeAt(0)),
    {name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256'}, false, ['sign']);
}
async function serviceToken(credentials, scope) {
  if (!credentials?.client_email || !credentials?.private_key) throw Error('service credentials missing');
  const now = Math.floor(Date.now() / 1000);
  const unsigned = b64url(JSON.stringify({alg:'RS256', typ:'JWT'})) + '.' +
    b64url(JSON.stringify({iss:credentials.client_email, scope, aud:GOOGLE_TOKEN, iat:now, exp:now+3000}));
  const key = await rsaPrivateKey(credentials.private_key);
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const reply = await fetch(GOOGLE_TOKEN, {
    method:'POST', headers:{'content-type':'application/x-www-form-urlencoded'},
    body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: unsigned + '.' + b64url(new Uint8Array(signature))}),
  });
  if (!reply.ok) throw Error('Google OAuth unavailable');
  const body = await reply.json();
  if (typeof body.access_token !== 'string') throw Error('OAuth token missing');
  return body.access_token;
}
async function verifyFirebase(token, projectId) {
  if (typeof token !== 'string' || token.length > 10000) throw Error('invalid firebase token');
  const parts = token.split('.');
  if (parts.length !== 3) throw Error('invalid firebase token');
  const header = JSON.parse(new TextDecoder().decode(unbase64url(parts[0])));
  const body = jwtBody(token);
  const now = Math.floor(Date.now()/1000);
  if (header.alg !== 'RS256' || !header.kid ||
      body.aud !== projectId || body.iss !== `https://securetoken.google.com/${projectId}` ||
      typeof body.sub !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(body.sub) ||
      !Number.isFinite(body.exp) || body.exp <= now || !Number.isFinite(body.iat) ||
      body.iat > now || !Number.isFinite(body.auth_time) || body.auth_time > now) {
    throw Error('Firebase token claims invalid');
  }
  const response = await fetch(FIREBASE_JWKS);
  if (!response.ok) throw Error('Firebase verification keys unavailable');
  const keys = await response.json();
  const jwk = keys.keys?.find(key => key.kid === header.kid && key.kty === 'RSA' && key.use === 'sig');
  if (!jwk) throw Error('Firebase key not found');
  const publicKey = await crypto.subtle.importKey('jwk', jwk, {name:'RSASSA-PKCS1-v1_5', hash:'SHA-256'}, false, ['verify']);
  const verified = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', publicKey, unbase64url(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`));
  if (!verified) throw Error('Firebase signature invalid');
  return body.sub;
}
async function appleToken(env) {
  if (!env.APPLE_PRIVATE_KEY_P8 || !env.APPLE_KEY_ID || !env.APPLE_ISSUER_ID || !env.APPLE_BUNDLE_ID) {
    throw Error('Apple server credentials incomplete');
  }
  const now = Math.floor(Date.now()/1000);
  const header = b64url(JSON.stringify({alg:'ES256', kid:env.APPLE_KEY_ID, typ:'JWT'}));
  const body = b64url(JSON.stringify({
    iss:env.APPLE_ISSUER_ID, iat:now, exp:now+300, aud:'appstoreconnect-v1', bid:env.APPLE_BUNDLE_ID,
  }));
  const key = await crypto.subtle.importKey('pkcs8', Uint8Array.from(
    atob(env.APPLE_PRIVATE_KEY_P8.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,'')),
    char => char.charCodeAt(0)), {name:'ECDSA', namedCurve:'P-256'}, false, ['sign']);
  const unsigned = `${header}.${body}`;
  const sig = await crypto.subtle.sign({name:'ECDSA', hash:'SHA-256'}, key, new TextEncoder().encode(unsigned));
  return `${unsigned}.${b64url(new Uint8Array(sig))}`;
}

/**
 * Data must come exclusively from an authenticated HTTPS response received
 * FROM Apple's subscription-status endpoint. Never accept this JWS from a
 * client as verification; it is decoded here only after server-to-server fetch.
 */
export function evaluateAppleStatus(statusResponse, bundleId, now = Date.now()) {
  const matches = [];
  for (const group of statusResponse?.data ?? []) {
    for (const last of group.lastTransactions ?? []) {
      if (![1, 4].includes(last.status) || typeof last.signedTransactionInfo !== 'string') continue;
      let transaction;
      try { transaction = jwtBody(last.signedTransactionInfo); } catch (_) { continue; }
      if (transaction.bundleId !== bundleId || transaction.productId !== PRODUCT ||
          transaction.type !== 'Auto-Renewable Subscription' ||
          !/^\d{8,30}$/.test(String(transaction.originalTransactionId ?? '')) ||
          !Number.isFinite(transaction.expiresDate) || transaction.expiresDate <= now ||
          transaction.revocationDate) continue;
      matches.push({
        platform:'ios',
        purchaseKey:`ios:${transaction.originalTransactionId}`,
        expiresMs:transaction.expiresDate,
      });
    }
  }
  return matches.sort((a,b) => b.expiresMs - a.expiresMs)[0] ?? null;
}
async function verifyApple(transactionId, env) {
  if (!/^\d{8,30}$/.test(transactionId)) throw Error('invalid Apple transaction ID');
  const token = await appleToken(env);
  for (const host of ['https://api.storekit.apple.com', 'https://api.storekit-sandbox.apple.com']) {
    const response = await fetch(`${host}/inApps/v1/subscriptions/${transactionId}`, {
      headers:{authorization:`Bearer ${token}`},
    });
    if (response.status === 404 && host.includes('api.storekit.apple.com')) continue;
    if (!response.ok) throw Error(`Apple subscription verification failed: ${response.status}`);
    return evaluateAppleStatus(await response.json(), env.APPLE_BUNDLE_ID);
  }
  return null;
}
export function evaluateGoogleSubscription(body, now = Date.now()) {
  if (!['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
    'SUBSCRIPTION_STATE_CANCELED'].includes(body?.subscriptionState)) return null;
  const expiresMs = Math.max(0, ...((body.lineItems ?? [])
    .filter(item => item.productId === PRODUCT)
    .map(item => Date.parse(item.expiryTime)).filter(Number.isFinite)));
  return expiresMs > now ? {platform:'android', expiresMs} : null;
}
async function verifyGoogle(purchaseToken, env) {
  if (!/^[a-zA-Z0-9._:-]{12,2048}$/.test(purchaseToken)) throw Error('invalid Google purchase token');
  if (!env.GOOGLE_PLAY_PACKAGE_NAME || !env.PLAY_SERVICE_ACCOUNT_JSON) {
    throw Error('Google Play service credentials incomplete');
  }
  const account = JSON.parse(env.PLAY_SERVICE_ACCOUNT_JSON);
  const token = await serviceToken(account, 'https://www.googleapis.com/auth/androidpublisher');
  const endpoint = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' +
    encodeURIComponent(env.GOOGLE_PLAY_PACKAGE_NAME) +
    '/purchases/subscriptionsv2/tokens/' + encodeURIComponent(purchaseToken);
  const response = await fetch(endpoint, {headers:{authorization:`Bearer ${token}`}});
  if (!response.ok) throw Error(`Google Play verification failed: ${response.status}`);
  const verified = evaluateGoogleSubscription(await response.json());
  return verified && {...verified, purchaseKey:`android:${purchaseToken}`};
}
function fsBase(project) {
  return `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(project)}/databases/(default)/documents`;
}
async function fsGet(path, token, transaction = null) {
  const url = new URL(path);
  if (transaction) url.searchParams.set('transaction', transaction);
  const r = await fetch(url, {headers:{authorization:`Bearer ${token}`}});
  if (r.status === 404) return null;
  if (!r.ok) throw Error(`Firestore read failed: ${r.status}`);
  return r.json();
}
async function fsPost(url, token, data) {
  const r = await fetch(url, {
    method:'POST', headers:{authorization:`Bearer ${token}`, 'content-type':'application/json'},
    body:JSON.stringify(data),
  });
  if (!r.ok) throw Error(`Firestore transaction failed: ${r.status}`);
  return r.json();
}
async function digest(input) {
  const hashed = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input));
  return Array.from(new Uint8Array(hashed), x => x.toString(16).padStart(2,'0')).join('');
}
function fieldStr(value) {return {stringValue:String(value)};}
function fieldTime(ms) {return {timestampValue:new Date(ms).toISOString()};}

async function grantVerifiedEntitlement(env, uid, state, firestoreToken) {
  const base = fsBase(env.FIREBASE_PROJECT_ID);
  const workspace = `${base}/workspaces/${encodeURIComponent(uid)}`;
  const entitlementPath = `${workspace}/entitlements/current`;
  const purchaseHash = await digest(state.purchaseKey);
  const claimPath = `${base}/billingClaims/${purchaseHash}`;
  // A single Firestore transaction prevents replay across accounts.
  for (let attempt = 0; attempt < 3; attempt++) {
    const begun = await fsPost(`${base}:beginTransaction`, firestoreToken, {});
    const transaction = begun.transaction;
    const [owner, workspaceDoc, current] = await Promise.all([
      fsGet(claimPath, firestoreToken, transaction),
      fsGet(workspace, firestoreToken, transaction),
      fsGet(entitlementPath, firestoreToken, transaction),
    ]);
    if (!workspaceDoc) throw Error('Firebase workspace missing');
    if (owner && owner.fields?.uid?.stringValue !== uid) {
      return {active:false, error:'purchase_already_linked'};
    }
    const previousMs = Date.parse(current?.fields?.expiresAt?.timestampValue ?? '') || 0;
    const previousSource = current?.fields?.source?.stringValue;
    const previousHash = current?.fields?.purchaseHash?.stringValue;
    const shouldUpdate = previousSource !== 'native_store' ||
      previousHash === purchaseHash || state.expiresMs >= previousMs;
    const writes = [];
    if (!owner) {
      writes.push({
        update:{name:claimPath, fields:{uid:fieldStr(uid), platform:fieldStr(state.platform),
          createdAt:fieldTime(Date.now())}},
        currentDocument:{exists:false},
      });
    }
    if (shouldUpdate) {
      writes.push({update:{name:entitlementPath,fields:{
        status:fieldStr('active'), source:fieldStr('native_store'),
        expiresAt:fieldTime(state.expiresMs), productId:fieldStr(PRODUCT),
        platform:fieldStr(state.platform), purchaseHash:fieldStr(purchaseHash),
        eventAtMs:{integerValue:String(Date.now())}, updatedAt:fieldTime(Date.now()),
      }}});
    }
    try {
      await fsPost(`${base}:commit`, firestoreToken, {transaction, writes});
      return {active:true, expiresAt:new Date(Math.max(state.expiresMs,
        shouldUpdate ? 0 : previousMs)).toISOString()};
    } catch (error) {
      if (attempt === 2) throw error;
    }
  }
  throw Error('unable to save entitlement');
}
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/health' && request.method === 'GET') {
      return json({ok:true});
    }
    if (url.pathname !== '/verify') return json({error:'not_found'},404);
    if (request.method !== 'POST') return json({error:'method_not_allowed'},405);
    if (!env.FIREBASE_SERVICE_ACCOUNT_JSON || !env.FIREBASE_PROJECT_ID ||
        !env.APPLE_BUNDLE_ID || !env.GOOGLE_PLAY_PACKAGE_NAME) {
      return json({error:'billing_not_configured'},503);
    }
    const bearer = request.headers.get('authorization') ?? '';
    if (!bearer.startsWith('Bearer ')) return json({error:'unauthorized'},401);
    let body;
    try {
      if (Number(request.headers.get('content-length') ?? 0) > MAX_BODY) return json({error:'too_large'},413);
      const raw = await request.text();
      if (raw.length > MAX_BODY) return json({error:'too_large'},413);
      body = JSON.parse(raw);
      if (body.productId !== PRODUCT || !['ios','android'].includes(body.platform) ||
          typeof body.proof !== 'string' || body.proof.length > 4096) {
        return json({error:'invalid_purchase'},400);
      }
    } catch (_) { return json({error:'invalid_json'},400); }
    let uid;
    try { uid = await verifyFirebase(bearer.slice(7), env.FIREBASE_PROJECT_ID); }
    catch (_) { return json({error:'unauthorized'},401); }
    try {
      const state = body.platform === 'ios'
        ? await verifyApple(body.proof, env)
        : await verifyGoogle(body.proof, env);
      if (!state) return json({active:false, error:'subscription_not_active'},422);
      const account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
      if (account.project_id !== env.FIREBASE_PROJECT_ID) throw Error('Firebase credential project mismatch');
      const token = await serviceToken(account, 'https://www.googleapis.com/auth/datastore');
      const result = await grantVerifiedEntitlement(env, uid, state, token);
      return json(result, result.active ? 200 : 409);
    } catch (error) {
      console.error('Store verification failed:', error?.message ?? 'unknown');
      return json({error:'verification_unavailable'},503);
    }
  },
};
