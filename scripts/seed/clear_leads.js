#!/usr/bin/env node
/**
 * Deletes all test leads from legacy root collection and M4LIFE SaaS subcollection.
 *
 * Usage:
 *   cd scripts/seed && npm install
 *   firebase login
 *   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"  # optional
 *   node clear_leads.js
 */

const admin = require('firebase-admin');
const { OAuth2Client } = require('google-auth-library');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'hitlook-app';
const COMPANY_ID = process.env.CLEAR_LEADS_COMPANY_ID || 'm4life';
const FIREBASE_CLI_CLIENT_ID =
  '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';

function docName(docPath) {
  return `projects/${PROJECT_ID}/databases/(default)/documents/${docPath}`;
}

async function getAccessToken() {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    if (admin.apps.length === 0) {
      admin.initializeApp({ projectId: PROJECT_ID });
    }
    const { access_token } = await admin.app().options.credential.getAccessToken();
    return { token: access_token, useAdminSdk: true };
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
  return { token, useAdminSdk: false };
}

async function firestoreApi(token, method, urlPath, body) {
  const url = `https://firestore.googleapis.com/v1/${urlPath}`;
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(body ? { 'Content-Type': 'application/json' } : {}),
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
  if (!res.ok && res.status !== 404) {
    const err = new Error(json.error?.message || res.statusText || text);
    err.status = res.status;
    throw err;
  }
  return json;
}

async function deleteAllInCollectionAdmin(db, collectionRef) {
  let total = 0;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const snapshot = await collectionRef.limit(500).get();
    if (snapshot.empty) break;
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    total += snapshot.size;
    if (snapshot.size < 500) break;
  }
  return total;
}

async function listAllDocsRest(token, collectionPath) {
  const names = [];
  let pageToken;
  do {
    let path = `${docName(collectionPath)}?pageSize=300`;
    if (pageToken) path += `&pageToken=${encodeURIComponent(pageToken)}`;
    const res = await firestoreApi(token, 'GET', path);
    for (const doc of res.documents || []) {
      names.push(doc.name);
    }
    pageToken = res.nextPageToken;
  } while (pageToken);
  return names;
}

async function deleteAllInCollectionRest(token, collectionPath) {
  const names = await listAllDocsRest(token, collectionPath);
  for (const name of names) {
    await firestoreApi(token, 'DELETE', name);
  }
  return names.length;
}

async function main() {
  const { token, useAdminSdk } = await getAccessToken();

  console.log(`\nHitLook clear_leads → project: ${PROJECT_ID}\n`);

  let legacyCount;
  let saasCount;

  if (useAdminSdk) {
    const db = admin.firestore();
    legacyCount = await deleteAllInCollectionAdmin(db, db.collection('leads'));
    saasCount = await deleteAllInCollectionAdmin(
      db,
      db.collection('companies').doc(COMPANY_ID).collection('leads'),
    );
  } else {
    legacyCount = await deleteAllInCollectionRest(token, 'leads');
    saasCount = await deleteAllInCollectionRest(
      token,
      `companies/${COMPANY_ID}/leads`,
    );
  }

  console.log(`  Deleted ${legacyCount} document(s) from leads (root)`);
  console.log(
    `  Deleted ${saasCount} document(s) from companies/${COMPANY_ID}/leads`,
  );

  let legacyLeft = 0;
  let saasLeft = 0;

  if (useAdminSdk) {
    const db = admin.firestore();
    legacyLeft = (await db.collection('leads').limit(1).get()).size;
    saasLeft = (
      await db
        .collection('companies')
        .doc(COMPANY_ID)
        .collection('leads')
        .limit(1)
        .get()
    ).size;
  } else {
    legacyLeft = (await listAllDocsRest(token, 'leads')).length;
    saasLeft = (await listAllDocsRest(token, `companies/${COMPANY_ID}/leads`))
      .length;
  }

  console.log('\n--- Verification ---');
  console.log(`  leads (root) empty: ${legacyLeft === 0 ? 'yes' : 'NO'}`);
  console.log(
    `  companies/${COMPANY_ID}/leads empty: ${saasLeft === 0 ? 'yes' : 'NO'}`,
  );
  console.log(`\nTotal deleted: ${legacyCount + saasCount}\n`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
