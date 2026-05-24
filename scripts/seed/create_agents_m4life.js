#!/usr/bin/env node
/**
 * Cria agentes M4LIFE com mustChangePassword: true no users/{uid}.
 *
 *   cd scripts/seed && node create_agents_m4life.js
 *
 * Variáveis: AGENT_EMAIL, AGENT_PASSWORD, AGENT_DISPLAY_NAME, AGENT_SLUG
 * companyId canônico: m4life
 */

const admin = require('firebase-admin');
const path = require('path');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'hitlook-app';
const COMPANY_ID = 'm4life';

const AGENT = {
  email: process.env.AGENT_EMAIL || 'agente@m4life.example',
  password: process.env.AGENT_PASSWORD || 'HitLook2026!',
  displayName: process.env.AGENT_DISPLAY_NAME || 'Agente M4LIFE',
  sellerId: process.env.AGENT_SLUG || 'agente-m4life',
};

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
  const auth = admin.auth();
  const db = admin.firestore();

  let user;
  try {
    user = await auth.getUserByEmail(AGENT.email);
    console.log(`Auth já existe: ${user.uid}`);
  } catch {
    user = await auth.createUser({
      email: AGENT.email,
      password: AGENT.password,
      displayName: AGENT.displayName,
    });
    console.log(`Auth criado: ${user.uid}`);
  }

  const uid = user.uid;
  const slug = AGENT.sellerId;

  await db.collection('users').doc(uid).set(
    {
      email: AGENT.email,
      displayName: AGENT.displayName,
      role: 'seller',
      companyId: COMPANY_ID,
      sellerId: slug,
      mustChangePassword: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const sellerPayload = {
    companyId: COMPANY_ID,
    displayName: AGENT.displayName,
    slug,
    userId: uid,
    email: AGENT.email,
    isActive: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db
    .collection('companies')
    .doc(COMPANY_ID)
    .collection('sellers')
    .doc(slug)
    .set(sellerPayload, { merge: true });

  await db.collection('seller_slugs').doc(slug).set(
    { companyId: COMPANY_ID, sellerId: slug, slug },
    { merge: true },
  );

  const agentMirror = {
    nome: AGENT.displayName,
    userId: uid,
    slug,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await db.collection('agents').doc(uid).set(agentMirror, { merge: true });
  await db.collection('agents').doc(slug).set(agentMirror, { merge: true });

  console.log('OK');
  console.log(`  companyId: ${COMPANY_ID}`);
  console.log(`  seller: ${slug}`);
  console.log(`  users/${uid}.mustChangePassword: true`);
  console.log(`  link: https://hitlook-app.web.app/a/${slug}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
