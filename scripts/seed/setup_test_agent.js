#!/usr/bin/env node
/**
 * Conta de AGENTE (seller) para testar foto no /perfil e link /a/slug.
 *
 *   cd scripts/seed && node setup_test_agent.js
 *   node setup_test_agent.js --force --i-understand-overwrite
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
  email: process.env.TEST_AGENT_EMAIL || 'diegom.ontime+agente@gmail.com',
  password: process.env.TEST_AGENT_PASSWORD || 'HitLook2026!',
  displayName: 'Diego Teste Agente',
  companyId: 'm4life',
  sellerId: 'diego-test',
};

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const force = args.includes('--force');

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
    if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT_ID });
    const { access_token } = await admin.app().options.credential.getAccessToken();
    return access_token;
  }
  const configPath = path.join(
    os.homedir(),
    '.config/configstore/firebase-tools.json',
  );
  if (!fs.existsSync(configPath)) {
    throw new Error('Run `firebase login` or set GOOGLE_APPLICATION_CREDENTIALS.');
  }
  const { tokens } = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const oauth2 = new OAuth2Client(FIREBASE_CLI_CLIENT_ID);
  oauth2.setCredentials({
    refresh_token: tokens.refresh_token,
    access_token: tokens.access_token,
    expiry_date: tokens.expires_at,
  });
  if (!tokens.access_token || Date.now() >= (tokens.expires_at || 0) - 60_000) {
    const { credentials } = await oauth2.refreshAccessToken();
    oauth2.setCredentials(credentials);
  }
  const { token } = await oauth2.getAccessToken();
  return token;
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
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(json.error?.message || res.statusText);
    err.status = res.status;
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
    if (e.status === 404) return null;
    throw e;
  }
}

async function createAuthUser(token) {
  if (dryRun) return 'dry-run-uid';
  let uid = await lookupUserByEmail(token, AGENT.email);
  if (uid) {
    console.log(`  EXISTS Auth ${AGENT.email} → ${uid}`);
    if (force) {
      await identityApi(token, 'POST', `projects/${PROJECT_ID}/accounts:update`, {
        localId: uid,
        password: AGENT.password,
        displayName: AGENT.displayName,
        returnSecureToken: false,
      });
      console.log('  UPDATED password (--force)');
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
  console.log(`  CREATE Auth ${AGENT.email} → ${uid}`);
  return uid;
}

function docName(docPath) {
  return `projects/${PROJECT_ID}/databases/(default)/documents/${docPath}`;
}

function encodeValue(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return { integerValue: String(v) };
  if (typeof v === 'string') return { stringValue: v };
  throw new Error(`Unsupported type: ${typeof v}`);
}

function encodeFields(data) {
  const fields = {};
  for (const [k, v] of Object.entries(data)) fields[k] = encodeValue(v);
  return fields;
}

async function firestoreApi(token, method, urlPath, body) {
  const res = await fetch(`https://firestore.googleapis.com/v1/${urlPath}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  const json = text ? JSON.parse(text) : {};
  if (!res.ok && res.status !== 404) {
    throw new Error(json.error?.message || text);
  }
  return { ok: res.ok, json };
}

async function commitSet(token, docPath, data) {
  if (dryRun) {
    console.log(`  WOULD SET ${docPath}`);
    return;
  }
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
        },
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
  console.log(`  SET ${docPath}`);
}

async function main() {
  loadDotEnv();
  const token = await getAccessToken();
  const slug = AGENT.sellerId;
  const uid = await createAuthUser(token);

  await commitSet(token, `users/${uid}`, {
    email: AGENT.email,
    role: 'seller',
    companyId: AGENT.companyId,
    sellerId: AGENT.sellerId,
    displayName: AGENT.displayName,
  });

  await commitSet(token, `companies/${AGENT.companyId}/sellers/${AGENT.sellerId}`, {
    companyId: AGENT.companyId,
    displayName: AGENT.displayName,
    slug,
    email: AGENT.email,
    userId: uid,
    photoUrl: '',
    bio: 'Conta de teste — foto e link público',
    phone: '17869738628',
    isActive: true,
    idioma: 'pt',
    nicho: 'seguro',
  });

  await commitSet(token, `seller_slugs/${slug}`, {
    companyId: AGENT.companyId,
    sellerId: AGENT.sellerId,
    slug,
  });

  const agentFields = {
    nome: AGENT.displayName,
    bio: 'Conta de teste — foto e link público',
    whatsapp: '17869738628',
    fotoUrl: '',
    userId: uid,
    slug,
    idioma: 'pt',
    nicho: 'seguro',
  };
  await commitSet(token, `agents/${uid}`, agentFields);
  await commitSet(token, `agents/${slug}`, agentFields);

  console.log('\n--- Conta de AGENTE (não admin) ---');
  console.log('  Login:  https://hitlook-app.web.app/login');
  console.log(`  Email:  ${AGENT.email}`);
  console.log(`  Senha:  ${AGENT.password}`);
  console.log('  Rotas:  /dashboard  /perfil');
  console.log(`  Link:   https://hitlook-app.web.app/a/${slug}\n`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
