#!/usr/bin/env node
/**
 * Ensures public link chain: seller_slugs → seller (userId) → agents/{uid} + agents/{slug}
 *
 *   cd scripts/seed && node sync_public_agent_profiles.js
 */
const { OAuth2Client } = require('google-auth-library');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = 'hitlook-app';
const FIREBASE_CLI_CLIENT_ID =
  '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';

const AGENTS = [
  {
    slug: 'diego-teste',
    companyId: 'm4life',
    sellerId: 'diego-teste',
    uid: 'kdlynxa7r1SEhfXzfcCBkEKQ2VI2',
    displayName: 'Diego Agente Teste',
  },
  {
    slug: 'renan',
    companyId: 'm4life',
    sellerId: 'renan',
    uid: null,
    displayName: 'Renan Sampaio',
  },
];

async function getAccessToken() {
  const configPath = path.join(
    os.homedir(),
    '.config/configstore/firebase-tools.json',
  );
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

function docName(docPath) {
  return `projects/${PROJECT_ID}/databases/(default)/documents/${docPath}`;
}

async function firestoreGet(token, docPath) {
  const res = await fetch(
    `https://firestore.googleapis.com/v1/${docName(docPath)}`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`${docPath}: ${res.status} ${await res.text()}`);
  return res.json();
}

function decodeFields(fields = {}) {
  const out = {};
  for (const [k, v] of Object.entries(fields)) {
    if (v.stringValue !== undefined) out[k] = v.stringValue;
    else if (v.booleanValue !== undefined) out[k] = v.booleanValue;
  }
  return out;
}

function encodeFields(data) {
  const fields = {};
  for (const [k, v] of Object.entries(data)) {
    if (v === undefined || v === null) continue;
    fields[k] = { stringValue: String(v) };
  }
  return fields;
}

async function firestorePatch(token, docPath, data) {
  const fieldPaths = Object.keys(data);
  const body = { fields: encodeFields(data) };
  const mask = fieldPaths.map((f) => `updateMask.fieldPaths=${f}`).join('&');
  const res = await fetch(
    `https://firestore.googleapis.com/v1/${docName(docPath)}?${mask}`,
    {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    },
  );
  if (!res.ok) throw new Error(`PATCH ${docPath}: ${res.status} ${await res.text()}`);
}

async function main() {
  const token = await getAccessToken();
  console.log('\n=== Public agent profile sync ===\n');

  for (const agent of AGENTS) {
    console.log(`--- ${agent.slug} ---`);

    const slugDoc = await firestoreGet(token, `seller_slugs/${agent.slug}`);
    console.log(
      `seller_slugs/${agent.slug}:`,
      slugDoc ? decodeFields(slugDoc.fields) : 'MISSING',
    );

    const sellerDoc = await firestoreGet(
      token,
      `companies/${agent.companyId}/sellers/${agent.sellerId}`,
    );
    const seller = sellerDoc ? decodeFields(sellerDoc.fields) : null;
    console.log(`seller:`, seller || 'MISSING');

    if (seller && agent.uid && seller.userId !== agent.uid) {
      console.log(`  FIX seller.userId → ${agent.uid}`);
      await firestorePatch(
        token,
        `companies/${agent.companyId}/sellers/${agent.sellerId}`,
        { userId: agent.uid },
      );
    }

    if (seller && !seller.displayName) {
      await firestorePatch(
        token,
        `companies/${agent.companyId}/sellers/${agent.sellerId}`,
        { displayName: agent.displayName },
      );
    }

    const uid = agent.uid || seller?.userId;
    if (uid) {
      const agentsUid = await firestoreGet(token, `agents/${uid}`);
      console.log(
        `agents/${uid}:`,
        agentsUid ? decodeFields(agentsUid.fields) : 'MISSING',
      );
      if (!agentsUid) {
        const payload = {
          nome: agent.displayName,
          userId: uid,
          slug: agent.slug,
          fotoUrl: '',
          photoUrl: '',
          bio: seller?.bio || '',
          whatsapp: seller?.phone || '',
          idioma: 'pt',
          nicho: 'seguro',
        };
        console.log(`  CREATE agents/${uid}`);
        await fetch(`https://firestore.googleapis.com/v1/${docName(`agents/${uid}`)}`, {
          method: 'PATCH',
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ fields: encodeFields(payload) }),
        });
      }
    }

    const mirrorPayload = {
      nome: seller?.displayName || agent.displayName,
      userId: uid || seller?.userId || '',
      slug: agent.slug,
      fotoUrl: seller?.photoUrl || '',
      photoUrl: seller?.photoUrl || '',
      bio: seller?.bio || '',
      whatsapp: seller?.phone || '',
      idioma: seller?.idioma || 'pt',
      nicho: seller?.nicho || 'seguro',
    };

    const agentsSlug = await firestoreGet(token, `agents/${agent.slug}`);
    console.log(
      `agents/${agent.slug}:`,
      agentsSlug ? decodeFields(agentsSlug.fields) : 'MISSING',
    );
    if (!agentsSlug && mirrorPayload.userId) {
      console.log(`  CREATE agents/${agent.slug}`);
      await fetch(`https://firestore.googleapis.com/v1/${docName(`agents/${agent.slug}`)}`, {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ fields: encodeFields(mirrorPayload) }),
      });
    }

    console.log('');
  }

  console.log('Done.\n');
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
