#!/usr/bin/env node
/**
 * Lists Firestore company documents whose id contains "m4life-usa" (legacy seed id).
 *
 *   cd scripts/seed && node check_company_ids.js
 */

const admin = require('firebase-admin');
const path = require('path');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'hitlook-app';

function init() {
  if (admin.apps.length) return;
  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (keyPath) {
    admin.initializeApp({
      credential: admin.credential.cert(require(path.resolve(keyPath))),
      projectId: PROJECT_ID,
    });
  } else {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
}

async function main() {
  init();
  const db = admin.firestore();
  const snap = await db.collection('companies').get();
  const legacy = snap.docs.filter((d) => d.id.includes('m4life-usa'));

  console.log(`Companies total: ${snap.size}`);
  if (legacy.length === 0) {
    console.log('OK — nenhum companyId "m4life-usa" encontrado.');
    return;
  }

  console.log('Encontrados (renomear/migrar manualmente para m4life):');
  for (const doc of legacy) {
    console.log(`  - companies/${doc.id}`, doc.data().name || '');
  }
  process.exitCode = 1;
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
