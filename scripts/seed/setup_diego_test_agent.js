#!/usr/bin/env node
/**
 * Diego test agent (seller) under M4LIFE — Auth + Firestore.
 *
 *   cd scripts/seed && npm install
 *   firebase login
 *   node setup_diego_test_agent.js
 *   node setup_diego_test_agent.js --force --i-understand-overwrite
 */

const admin = require('firebase-admin');
const { OAuth2Client } = require('google-auth-library');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'hitlook-app';
const FIREBASE_CLI_CLIENT_ID =
  '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';

const AGENT = {
  email: 'diegoricardomartinsrocha@gmail.com',
  password: '123456',
  displayName: 'Diego Agente Teste',
  companyId: 'm4life',
  sellerId: 'diego-teste',
  slug: 'diego-teste',
};

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const force = args.includes('--force');

if (force && !args.includes('--i-understand-overwrite')) {
  console.error('\nUse: --force --i-understand-overwrite\n');
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
    return { token: access_token, mode: 'service-account' };
  }

  const configPath = path.join(
    os.homedir(),
    '.config/configstore/firebase-tools.json',
  );
  if (!fs.existsSync(configPath)) {
    throw new Error('Run `firebase login` or set GOOGLE_APPLICATION_CREDENTIALS.');
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
  return { token, mode: 'firebase-cli' };
}

async function identityApi(token, method, urlPath, body) {
  const res = await fetch(`https://identitytoolkit.googleapis.com/v1/${urlPath}`, {
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
    console.log('  WOULD CREATE Auth:', AGENT.email);
    return 'dry-run-uid';
  }

  let uid = await lookupUserByEmail(token, AGENT.email);
  if (uid) {
    console.log(`  EXISTS Auth ${AGENT.email} → uid ${uid}`);
    if (force) {
      await identityApi(token, 'POST', `projects/${PROJECT_ID}/accounts:update`, {
        localId: uid,
        email: AGENT.email,
        password: AGENT.password,
        displayName: AGENT.displayName,
        returnSecureToken: false,
      });
      console.log('  UPDATED Auth password/displayName (--force)');
    }
    return uid;
  }

  const res = await identityApi(token, 'POST', `projects/${PROJECT_ID}/accounts`, {
    email: AGENT.email,
    password: AGENT.password,
    displayName: AGENT.displayName,
    emailVerified: false,
  });

  uid = res.localId;
  if (!uid) throw new Error('Auth create did not return localId');
  console.log(`  CREATE Auth ${AGENT.email} → uid ${uid}`);
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
    else if (wrapped.nullValue !== undefined) out[key] = null;
  }
  return out;
}

async function firestoreApi(token, method, urlPath, body) {
  const res = await fetch(`https://firestore.googleapis.com/v1/${urlPath}`, {
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

async function commitSet(token, docPath, data) {
  if (dryRun) {
    console.log(`  WOULD SET ${docPath}`);
    return 'dry-run';
  }

  const exists = await docExists(token, docPath);
  const name = docName(docPath);
  const fieldPaths = Object.keys(data);

  await firestoreApi(
    token,
    'POST',
    `projects/${PROJECT_ID}/databases/(default)/documents:commit`,
    {
      writes: [
        {
          update: { name, fields: encodeFields(data) },
          updateMask: { fieldPaths },
          ...(exists ? {} : { currentDocument: { exists: false } }),
        },
        {
          transform: {
            document: name,
            fieldTransforms: [
              { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
              ...(exists
                ? []
                : [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }]),
            ],
          },
        },
      ],
    },
  );

  console.log(`  ${exists ? 'UPDATE' : 'CREATE'} ${docPath}`);
  return exists ? 'updated' : 'created';
}

async function verifyDoc(token, docPath, expectedKeys) {
  const res = await firestoreApi(token, 'GET', docName(docPath));
  const data = decodeFields(res.fields);
  for (const key of expectedKeys) {
    if (!(key in data)) {
      throw new Error(`Missing field ${key} on ${docPath}`);
    }
  }
  console.log(`  OK    ${docPath}`);
  return data;
}

async function main() {
  loadDotEnv();

  const { token, mode } = await getAccessToken();
  console.log(`\nHitLook setup_diego_test_agent → ${PROJECT_ID}`);
  console.log(`Auth: ${mode}\n`);
  if (dryRun) console.log('DRY RUN\n');

  const uid = await createAuthUser(token);

  await commitSet(token, `users/${uid}`, {
    email: AGENT.email,
    role: 'seller',
    companyId: AGENT.companyId,
    sellerId: AGENT.sellerId,
    displayName: AGENT.displayName,
  });

  await commitSet(token, `companies/${AGENT.companyId}/sellers/${AGENT.sellerId}`, {
    displayName: AGENT.displayName,
    slug: AGENT.slug,
    email: AGENT.email,
    userId: uid,
    photoUrl: '',
    bio: 'Agente de teste',
    phone: '',
    isActive: true,
    companyId: AGENT.companyId,
  });

  await commitSet(token, `seller_slugs/${AGENT.slug}`, {
    companyId: AGENT.companyId,
    sellerId: AGENT.sellerId,
  });

  const agentPayload = {
    nome: AGENT.displayName,
    bio: 'Agente de teste',
    whatsapp: '',
    fotoUrl: '',
    userId: uid,
    slug: AGENT.slug,
    idioma: 'pt',
    nicho: 'seguro',
  };
  await commitSet(token, `agents/${uid}`, agentPayload);
  await commitSet(token, `agents/${AGENT.slug}`, agentPayload);

  if (!dryRun) {
    console.log('\n--- Verification ---');
    await verifyDoc(token, `users/${uid}`, [
      'email',
      'role',
      'companyId',
      'sellerId',
      'displayName',
    ]);
    await verifyDoc(token, `companies/${AGENT.companyId}/sellers/${AGENT.sellerId}`, [
      'displayName',
      'slug',
      'email',
      'userId',
      'companyId',
    ]);
    await verifyDoc(token, `seller_slugs/${AGENT.slug}`, [
      'companyId',
      'sellerId',
    ]);
  }

  console.log('\n--- Resultado ---');
  console.log(`  UID:    ${uid}`);
  console.log(`  Login:  https://hitlook-app.web.app/login`);
  console.log(`  Email:  ${AGENT.email}`);
  console.log(`  Senha:  ${AGENT.password}`);
  console.log(`  Perfil: https://hitlook-app.web.app/perfil`);
  console.log(`  Link:   https://hitlook-app.web.app/a/${AGENT.slug}\n`);
}

main().catch((err) => {
  console.error('\nFailed:', err.message || err);
  if (err.details) console.error(JSON.stringify(err.details, null, 2));
  process.exit(1);
});
