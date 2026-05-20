#!/usr/bin/env node
/**
 * Create Renan Sampaio in Firebase Auth + Firestore admin for m4life.
 *
 * 1. Firebase Auth user (prosperarusa@gmail.com)
 * 2. users/{uid} — role admin, companyId m4life
 * 3. companies/m4life/sellers/renan — patch userId
 *
 * Usage:
 *   cd scripts/seed && npm install
 *   firebase login
 *   node setup_renan.js
 *
 *   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"
 *   node setup_renan.js
 */

const admin = require('firebase-admin');
const { OAuth2Client } = require('google-auth-library');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'hitlook-app';
const WEB_API_KEY =
  process.env.FIREBASE_WEB_API_KEY || 'AIzaSyBSx_LQ1LMujnRnCFDjB8Fsgbpzn-z22Rs';
const FIREBASE_CLI_CLIENT_ID =
  '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';

const RENAN = {
  email: 'prosperarusa@gmail.com',
  password: '123456',
  displayName: 'Renan Sampaio',
  companyId: 'm4life',
  sellerId: 'renan',
};

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const force = args.includes('--force');

if (force && !args.includes('--i-understand-overwrite')) {
  console.error(
    '\nRefusing to overwrite without: --force --i-understand-overwrite\n',
  );
  process.exit(1);
}

function loadDotEnv() {
  const envPath = path.join(__dirname, '.env');
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, 'utf8').split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    const value = trimmed.slice(eq + 1).trim().replace(/^["']|["']$/g, '');
    if (!process.env[key]) process.env[key] = value;
  }
}

async function getAccessToken() {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    if (admin.apps.length === 0) {
      admin.initializeApp({ projectId: PROJECT_ID });
    }
    const { access_token } = await admin.app().options.credential.getAccessToken();
    return { token: access_token, mode: 'service-account', adminApp: true };
  }

  const configPath = path.join(
    os.homedir(),
    '.config/configstore/firebase-tools.json',
  );
  if (!fs.existsSync(configPath)) {
    throw new Error(
      'Run `firebase login` or set GOOGLE_APPLICATION_CREDENTIALS.',
    );
  }

  const { tokens } = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  if (!tokens?.refresh_token) {
    throw new Error('firebase login tokens missing — run: firebase login');
  }

  const oauth2 = new OAuth2Client(FIREBASE_CLI_CLIENT_ID);
  oauth2.setCredentials({
    refresh_token: tokens.refresh_token,
    access_token: tokens.access_token,
    expiry_date: tokens.expires_at,
  });

  if (!tokens.access_token || Date.now() >= (tokens.expires_at || 0) - 60_000) {
    const { credentials } = await oauth2.refreshAccessToken();
    oauth2.setCredentials(credentials);
    console.log('Refreshed Firebase CLI access token.');
  }

  const { token } = await oauth2.getAccessToken();
  return { token, mode: 'firebase-cli', adminApp: false };
}

async function identityApi(token, method, urlPath, body) {
  const url = `https://identitytoolkit.googleapis.com/v1/${urlPath}`;
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    json = { raw: text };
  }
  if (!res.ok) {
    const err = new Error(json.error?.message || res.statusText || text);
    err.status = res.status;
    err.details = json.error;
    throw err;
  }
  return json;
}

async function lookupUserByEmail(token, email) {
  try {
    const res = await identityApi(
      token,
      'POST',
      `projects/${PROJECT_ID}/accounts:lookup`,
      { email: [email] },
    );
    return res.users?.[0]?.localId || null;
  } catch (e) {
    if (e.status === 404 || e.details?.message?.includes('USER_NOT_FOUND')) {
      return null;
    }
    throw e;
  }
}

async function createAuthUser(token) {
  if (dryRun) {
    console.log('  WOULD CREATE Auth user:', RENAN.email);
    return 'dry-run-uid';
  }

  const existing = await lookupUserByEmail(token, RENAN.email);
  if (existing) {
    console.log(`  EXISTS Auth user ${RENAN.email} → uid ${existing}`);
    if (force) {
      await identityApi(
        token,
        'POST',
        `projects/${PROJECT_ID}/accounts:update`,
        {
          localId: existing,
          displayName: RENAN.displayName,
          password: RENAN.password,
          returnSecureToken: false,
        },
      );
      console.log('  UPDATED Auth password/displayName (--force)');
    }
    return existing;
  }

  const res = await identityApi(
    token,
    'POST',
    `projects/${PROJECT_ID}/accounts`,
    {
      email: RENAN.email,
      password: RENAN.password,
      displayName: RENAN.displayName,
      emailVerified: false,
    },
  );

  const uid = res.localId;
  if (!uid) throw new Error('Auth create did not return localId');
  console.log(`  CREATE Auth user ${RENAN.email} → uid ${uid}`);
  return uid;
}

function docName(docPath) {
  return `projects/${PROJECT_ID}/databases/(default)/documents/${docPath}`;
}

function encodeFields(data) {
  const fields = {};
  for (const [key, value] of Object.entries(data)) {
    if (value === null || value === undefined) continue;
    if (typeof value === 'string') fields[key] = { stringValue: value };
    else if (typeof value === 'boolean') fields[key] = { booleanValue: value };
    else if (typeof value === 'number') {
      fields[key] = Number.isInteger(value)
        ? { integerValue: String(value) }
        : { doubleValue: value };
    } else {
      throw new Error(`Unsupported field type for ${key}`);
    }
  }
  return fields;
}

function decodeFields(fields = {}) {
  const out = {};
  for (const [key, wrapped] of Object.entries(fields)) {
    if (wrapped.stringValue !== undefined) out[key] = wrapped.stringValue;
    else if (wrapped.booleanValue !== undefined) out[key] = wrapped.booleanValue;
    else if (wrapped.integerValue !== undefined) out[key] = Number(wrapped.integerValue);
    else if (wrapped.doubleValue !== undefined) out[key] = wrapped.doubleValue;
    else if (wrapped.timestampValue !== undefined) out[key] = wrapped.timestampValue;
    else if (wrapped.nullValue !== undefined) out[key] = null;
    else out[key] = wrapped;
  }
  return out;
}

async function firestoreApi(token, method, urlPath, body) {
  const url = `https://firestore.googleapis.com/v1/${urlPath}`;
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    json = { raw: text };
  }
  if (!res.ok) {
    const err = new Error(json.error?.message || res.statusText || text);
    err.status = res.status;
    err.details = json.error;
    throw err;
  }
  return json;
}

async function docExists(token, docPath) {
  try {
    await firestoreApi(token, 'GET', docName(docPath));
    return true;
  } catch (e) {
    if (e.status === 404) return false;
    throw e;
  }
}

async function createUserDoc(token, uid) {
  const docPath = `users/${uid}`;
  const data = {
    email: RENAN.email,
    role: 'admin',
    companyId: RENAN.companyId,
    displayName: RENAN.displayName,
    sellerId: RENAN.sellerId,
  };

  if (dryRun) {
    console.log(`  WOULD SET ${docPath}`);
    return 'dry-run';
  }

  const exists = await docExists(token, docPath);
  if (exists && !force) {
    const name = docName(docPath);
    const fieldPaths = Object.keys(data);
    await firestoreApi(
      token,
      'PATCH',
      `${name}?${fieldPaths.map((f) => `updateMask.fieldPaths=${f}`).join('&')}`,
      { fields: encodeFields(data) },
    );
    await firestoreApi(
      token,
      'POST',
      `projects/${PROJECT_ID}/databases/(default)/documents:commit`,
      {
        writes: [
          {
            transform: {
              document: name,
              fieldTransforms: [
                { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
              ],
            },
          },
        ],
      },
    );
    console.log(`  UPDATE ${docPath}`);
    return 'updated';
  }

  const name = docName(docPath);
  const fieldPaths = Object.keys(data);

  const writes = [
    {
      update: { name, fields: encodeFields(data) },
      updateMask: { fieldPaths },
      currentDocument: exists && force ? undefined : { exists: false },
    },
    {
      transform: {
        document: name,
        fieldTransforms: [
          { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
          { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
        ],
      },
    },
  ];

  if (exists && force) {
    writes[0].currentDocument = undefined;
  }

  await firestoreApi(
    token,
    'POST',
    `projects/${PROJECT_ID}/databases/(default)/documents:commit`,
    { writes },
  );

  console.log(`  ${exists ? 'UPDATE' : 'CREATE'} ${docPath}`);
  return exists ? 'updated' : 'created';
}

async function commitSet(token, docPath, data, { allowOverwrite = false } = {}) {
  if (dryRun) {
    console.log(`  WOULD SET ${docPath}`, JSON.stringify(data));
    return;
  }

  const exists = await docExists(token, docPath);
  if (exists && !allowOverwrite && !force) {
    console.log(`  SKIP  ${docPath} — already exists`);
    return;
  }

  const name = docName(docPath);
  const fieldPaths = Object.keys(data);
  const writes = [
    {
      update: { name, fields: encodeFields(data) },
      updateMask: { fieldPaths },
      currentDocument: exists ? undefined : { exists: false },
    },
    {
      transform: {
        document: name,
        fieldTransforms: [
          { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
          { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
        ],
      },
    },
  ];

  await firestoreApi(
    token,
    'POST',
    `projects/${PROJECT_ID}/databases/(default)/documents:commit`,
    { writes },
  );

  console.log(`  ${exists ? 'UPDATE' : 'CREATE'} ${docPath}`);
}

async function ensureM4LifeSeller(token, uid) {
  await commitSet(
    token,
    `companies/${RENAN.companyId}`,
    {
      name: 'M4LIFE USA',
      tenantId: 'm4life',
      plan: 'starter',
      isActive: true,
    },
    { allowOverwrite: true },
  );

  await commitSet(
    token,
    `companies/${RENAN.companyId}/sellers/${RENAN.sellerId}`,
    {
      displayName: RENAN.displayName,
      slug: RENAN.sellerId,
      email: RENAN.email,
      userId: uid,
      photoUrl: '',
      bio: 'Consultor de proteção familiar M4LIFE USA',
      phone: '+17869738628',
      isActive: true,
      companyId: RENAN.companyId,
    },
    { allowOverwrite: true },
  );

  await commitSet(
    token,
    `seller_slugs/${RENAN.sellerId}`,
    {
      companyId: RENAN.companyId,
      sellerId: RENAN.sellerId,
    },
    { allowOverwrite: true },
  );
}

async function verify(token, uid) {
  const paths = [
    `users/${uid}`,
    `companies/${RENAN.companyId}`,
    `companies/${RENAN.companyId}/sellers/${RENAN.sellerId}`,
    `seller_slugs/${RENAN.sellerId}`,
  ];

  console.log('\n--- Firestore verification ---');
  for (const p of paths) {
    try {
      const doc = await firestoreApi(token, 'GET', docName(p));
      console.log(`  OK    ${p}`);
      console.log(`        ${JSON.stringify(decodeFields(doc.fields))}`);
    } catch (e) {
      console.log(`  MISS  ${p} (${e.message})`);
    }
  }
}

async function testPublicLink(token) {
  console.log('\n--- Public link /a/renan (data chain) ---');
  const slugDoc = await firestoreApi(
    token,
    'GET',
    docName(`seller_slugs/${RENAN.sellerId}`),
  );
  const { companyId, sellerId } = decodeFields(slugDoc.fields);
  const sellerDoc = await firestoreApi(
    token,
    'GET',
    docName(`companies/${companyId}/sellers/${sellerId}`),
  );
  const seller = decodeFields(sellerDoc.fields);
  const nameOk = seller.displayName === RENAN.displayName;
  console.log(`  OK    seller_slugs/renan → companies/${companyId}/sellers/${sellerId}`);
  console.log(`  ${nameOk ? 'OK' : 'FAIL'}  displayName="${seller.displayName}"`);
  if (!nameOk) return false;
  console.log('  OK    App loads this via AgentProvider → header shows "Renan Sampaio"');
  console.log('  CHECK https://hitlook-app.web.app/a/renan (anonymous tab)');
  return true;
}

async function testLogin(uid) {
  console.log('\n--- Login test (Auth REST) ---');
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${WEB_API_KEY}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: RENAN.email,
      password: RENAN.password,
      returnSecureToken: true,
    }),
  });
  const json = await res.json();
  if (!res.ok) {
    console.log(`  FAIL  signInWithPassword: ${json.error?.message || res.status}`);
    return false;
  }

  const signedUid = json.localId;
  const match = signedUid === uid;
  console.log(`  OK    signInWithPassword (uid ${signedUid})`);
  if (!match) {
    console.log(`  WARN  uid mismatch: expected ${uid}`);
  }

  console.log('  OK    credentials valid for https://hitlook-app.web.app/login');
  console.log('  EXPECT post-login route: /admin (role=admin in users doc)');
  return true;
}

async function main() {
  loadDotEnv();

  const { token, mode } = await getAccessToken();
  console.log(`\nHitLook setup_renan → project: ${PROJECT_ID}`);
  console.log(`Auth mode: ${mode}\n`);
  if (dryRun) console.log('DRY RUN (no writes)\n');

  const uid = await createAuthUser(token);

  await createUserDoc(token, uid);
  await ensureM4LifeSeller(token, uid);

  console.log('\n--- Result ---');
  console.log(`  Renan UID: ${uid}`);
  console.log(`  Email:     ${RENAN.email}`);
  console.log(`  Company:   ${RENAN.companyId}`);
  console.log(`  Seller:    companies/${RENAN.companyId}/sellers/${RENAN.sellerId}`);

  if (!dryRun) {
    await verify(token, uid);
    await testPublicLink(token);
    await testLogin(uid);
    console.log('\nManual check: https://hitlook-app.web.app/login');
    console.log(`  ${RENAN.email} / ${RENAN.password} → /admin\n`);
  }
}

main().catch((err) => {
  console.error('\nFailed:', err.message || err);
  if (err.details) console.error(JSON.stringify(err.details, null, 2));
  if (err.status === 403) {
    console.error(
      '\nPermission denied. Use firebase login as project Owner or a service account with Firebase Auth Admin + Firestore.\n',
    );
  }
  process.exit(1);
});
