#!/usr/bin/env node
/**
 * Verifica leads do Diego (uid + sellerId diego-teste).
 * cd scripts/seed && node check_diego_leads.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'hitlook-app';
const UID = process.env.CHECK_UID || 'kdlynxa7r1SEhfXzfcCBkEKQ2VI2';
const SELLER_ID = process.env.CHECK_SELLER_ID || 'diego-teste';
const COMPANY_ID = process.env.CHECK_COMPANY_ID || 'm4life';

function init() {
  if (admin.apps.length) return;
  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (keyPath && fs.existsSync(keyPath)) {
    admin.initializeApp({
      credential: admin.credential.cert(require(path.resolve(keyPath))),
      projectId: PROJECT_ID,
    });
    return;
  }
  const configPath = path.join(
    os.homedir(),
    '.config/configstore/firebase-tools.json',
  );
  if (fs.existsSync(configPath)) {
    admin.initializeApp({ projectId: PROJECT_ID });
    return;
  }
  throw new Error('Set GOOGLE_APPLICATION_CREDENTIALS or run firebase login');
}

async function check() {
  init();
  const db = admin.firestore();

  console.log('Projeto:', PROJECT_ID);
  console.log('UID:', UID);
  console.log('sellerId:', SELLER_ID);
  console.log('---');

  const leads = await db
    .collection('leads')
    .where('agentId', '==', UID)
    .get();
  console.log('leads raiz:', leads.size);

  let saasLeads;
  try {
    saasLeads = await db
      .collection('companies')
      .doc(COMPANY_ID)
      .collection('leads')
      .where('sellerId', '==', SELLER_ID)
      .get();
    console.log(`companies/${COMPANY_ID}/leads (sellerId):`, saasLeads.size);
  } catch (e) {
    console.log('companies leads sellerId query ERRO:', e.message);
    saasLeads = { size: 0, docs: [] };
  }

  try {
    const byAgent = await db
      .collection('companies')
      .doc(COMPANY_ID)
      .collection('leads')
      .where('agentId', '==', UID)
      .get();
    console.log(`companies/${COMPANY_ID}/leads (agentId):`, byAgent.size);
  } catch (e) {
    console.log('companies leads agentId query ERRO:', e.message);
  }

  if (leads.size > 0) {
    console.log('\nprimeiro lead raiz:');
    console.log(JSON.stringify(leads.docs[0].data(), null, 2));
  }
  if (saasLeads.size > 0) {
    console.log('\nprimeiro lead SaaS:');
    console.log(JSON.stringify(saasLeads.docs[0].data(), null, 2));
  }

  const userSnap = await db.collection('users').doc(UID).get();
  console.log('\nusers/' + UID + ' exists:', userSnap.exists);
  if (userSnap.exists) {
    console.log(JSON.stringify(userSnap.data(), null, 2));
  }
}

check()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
