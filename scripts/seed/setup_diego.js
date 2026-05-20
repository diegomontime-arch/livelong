#!/usr/bin/env node
/**
 * Seed Diego Rocha as HitLook admin master + company/seller/slug.
 *
 * Documents:
 *   users/SiG1jKPkftSu72PMZZD2ieHEw472
 *   companies/hitlook
 *   companies/hitlook/sellers/diego
 *   seller_slugs/diego
 *
 * Usage:
 *   cd scripts/seed && npm install
 *   firebase login
 *   node setup_diego.js
 *
 * Or with a service account:
 *   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"
 *   node setup_diego.js
 *
 *   node setup_diego.js --dry-run
 *   node setup_diego.js --force --i-understand-overwrite
 */

const admin = require('firebase-admin');
const { OAuth2Client } = require('google-auth-library');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'hitlook-app';
const FIREBASE_CLI_CLIENT_ID =
  '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';

const DIEGO = {
  uid: 'SiG1jKPkftSu72PMZZD2ieHEw472',
  email: 'diegom.ontime@gmail.com',
  displayName: 'Diego Rocha',
  companyId: 'hitlook',
  sellerId: 'diego',
  slug: 'diego',
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
    const app = admin.app();
    const credential = app.options.credential;
    const { access_token } = await credential.getAccessToken();
    return { token: access_token, mode: 'service-account' };
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
  return { token, mode: 'firebase-cli' };
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

async function api(token, method, urlPath, body) {
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
    await api(token, 'GET', docName(docPath));
    return true;
  } catch (e) {
    if (e.status === 404) return false;
    throw e;
  }
}

async function commitWrite(token, docPath, data, { skipIfExists }) {
  const name = docName(docPath);
  const fieldPaths = Object.keys(data);

  if (skipIfExists) {
    const exists = await docExists(token, docPath);
    if (exists) {
      console.log(`  SKIP  ${docPath} — already exists`);
      return 'skipped';
    }
  }

  const writes = [
    {
      update: { name, fields: encodeFields(data) },
      updateMask: { fieldPaths },
      currentDocument: force ? undefined : { exists: false },
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

  if (force) {
    writes[0].currentDocument = undefined;
  }

  await api(
    token,
    'POST',
    `projects/${PROJECT_ID}/databases/(default)/documents:commit`,
    { writes },
  );

  console.log(`  ${force ? 'FORCE' : 'CREATE'} ${docPath}`);
  return force ? 'overwritten' : 'created';
}

async function safeSet(token, docPath, data) {
  if (dryRun) {
    console.log(`  WOULD SET ${docPath}`);
    console.log(`            ${JSON.stringify(data)}`);
    return 'dry-run';
  }
  return commitWrite(token, docPath, data, { skipIfExists: !force });
}

async function verify(token) {
  const paths = [
    `users/${DIEGO.uid}`,
    `companies/${DIEGO.companyId}`,
    `companies/${DIEGO.companyId}/sellers/${DIEGO.sellerId}`,
    `seller_slugs/${DIEGO.slug}`,
  ];

  console.log('\n--- Verification ---');
  for (const p of paths) {
    try {
      const doc = await api(token, 'GET', docName(p));
      console.log(`  OK    ${p}`);
      console.log(`        ${JSON.stringify(decodeFields(doc.fields))}`);
    } catch (e) {
      console.log(`  MISS  ${p} (${e.message})`);
    }
  }
}

async function main() {
  loadDotEnv();

  const { token, mode } = await getAccessToken();
  console.log(`\nHitLook setup_diego → project: ${PROJECT_ID}`);
  console.log(`Auth: ${mode}\n`);
  if (dryRun) console.log('DRY RUN (no writes)\n');

  const stats = { created: 0, skipped: 0 };

  const track = (r) => {
    if (r === 'created' || r === 'overwritten' || r === 'dry-run') stats.created++;
    else if (r === 'skipped') stats.skipped++;
  };

  track(
    await safeSet(token, `users/${DIEGO.uid}`, {
      email: DIEGO.email,
      role: 'admin',
      companyId: DIEGO.companyId,
      displayName: DIEGO.displayName,
    }),
  );

  track(
    await safeSet(token, `companies/${DIEGO.companyId}`, {
      name: 'HitLook',
      tenantId: 'hitlook',
      plan: 'starter',
      isActive: true,
    }),
  );

  track(
    await safeSet(token, `companies/${DIEGO.companyId}/sellers/${DIEGO.sellerId}`, {
      companyId: DIEGO.companyId,
      displayName: DIEGO.displayName,
      slug: DIEGO.slug,
      email: DIEGO.email,
      userId: DIEGO.uid,
      photoUrl: '',
      bio: 'Fundador HitLook',
      phone: '',
      isActive: true,
    }),
  );

  track(
    await safeSet(token, `seller_slugs/${DIEGO.slug}`, {
      companyId: DIEGO.companyId,
      sellerId: DIEGO.sellerId,
      slug: DIEGO.slug,
    }),
  );

  console.log('\n--- Summary ---');
  console.log(`  written: ${stats.created}`);
  console.log(`  skipped: ${stats.skipped}`);

  if (!dryRun) {
    await verify(token);
    console.log('\nLogin test: https://hitlook-app.web.app/login');
    console.log(`  email: ${DIEGO.email}`);
    console.log('  expected route after login: /admin\n');
  }
}

main().catch((err) => {
  console.error('\nFailed:', err.message || err);
  if (err.details) console.error(JSON.stringify(err.details, null, 2));
  if (err.status === 403) {
    console.error(
      '\nPermission denied. Use a project Owner account (firebase login) or a service account with Firestore Admin.\n',
    );
  }
  process.exit(1);
});
