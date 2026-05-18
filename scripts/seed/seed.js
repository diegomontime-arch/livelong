#!/usr/bin/env node
/**
 * Safe Firestore seed for HitLook SaaS (local / dev).
 *
 * Creates (by default, skip if exists):
 *   tenants/m4life
 *   companies/m4life-usa
 *   companies/m4life-usa/sellers/{sellerId}
 *   seller_slugs/m4life
 *   users/{adminUid}  — only when ADMIN_UID or ADMIN_EMAIL is set
 *
 * Usage:
 *   npm install
 *   npm run seed:dry-run
 *   npm run seed
 *   npm run seed -- --force          # overwrite existing docs (explicit)
 *   npm run seed -- --dry-run
 *
 * Emulator:
 *   firebase emulators:start --only firestore,auth
 *   npm run seed:emulator
 *
 * Production / shared dev project:
 *   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"
 *   export ADMIN_UID="your-auth-uid"
 *   npm run seed
 */

const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');
const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

const DEFAULTS = {
  tenantId: 'm4life',
  companyId: process.env.SEED_COMPANY_ID || 'm4life-usa',
  sellerId: process.env.SEED_SELLER_ID || 'seller-m4life-1',
  sellerSlug: process.env.SEED_SELLER_SLUG || 'm4life',
  projectId: process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'hitlook-app',
};

const TENANT = {
  name: 'M4LIFE',
  primaryColorHex: 'D4AF37',
  isActive: true,
};

const COMPANY = {
  tenantId: DEFAULTS.tenantId,
  name: 'M4LIFE USA',
  plan: 'starter',
  isActive: true,
};

const SELLER = {
  displayName: 'M4LIFE Consultant',
  slug: DEFAULTS.sellerSlug,
  bio: 'Life insurance consultant for Latino families in the US.',
  email: process.env.SEED_SELLER_EMAIL || 'consultant@m4life.example',
  phone: process.env.SEED_SELLER_PHONE || '',
  isActive: true,
};

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const force = args.includes('--force');

if (force && !args.includes('--i-understand-overwrite')) {
  console.error(
    '\nRefusing to overwrite without explicit confirmation.\n' +
      'Re-run with:  npm run seed -- --force --i-understand-overwrite\n',
  );
  process.exit(1);
}

loadDotEnv();

// ---------------------------------------------------------------------------
// Firebase Admin
// ---------------------------------------------------------------------------

function initFirebase() {
  if (admin.apps.length > 0) return;

  const projectId = DEFAULTS.projectId;
  const usingEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

  if (usingEmulator) {
    console.log(`Using Firestore emulator: ${process.env.FIRESTORE_EMULATOR_HOST}`);
    admin.initializeApp({ projectId });
    return;
  }

  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.warn(
      'Warning: GOOGLE_APPLICATION_CREDENTIALS is not set.\n' +
        'Using Application Default Credentials (e.g. gcloud auth application-default login).\n' +
        'For local dev, prefer a service account key from Firebase Console → Project settings → Service accounts.\n',
    );
  }

  admin.initializeApp({ projectId });
  console.log(`Target project: ${projectId}`);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function loadDotEnv() {
  const envPath = path.join(__dirname, '.env');
  if (!fs.existsSync(envPath)) return;
  const lines = fs.readFileSync(envPath, 'utf8').split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    const value = trimmed.slice(eq + 1).trim().replace(/^["']|["']$/g, '');
    if (!process.env[key]) process.env[key] = value;
  }
}

async function docExists(ref) {
  const snap = await ref.get();
  return snap.exists;
}

/**
 * Create document only if missing, unless --force.
 * @returns {'created'|'skipped'|'overwritten'}
 */
async function safeSet(ref, data, label) {
  if (dryRun) {
    const action = force ? 'WOULD SET (force)' : 'WOULD CREATE (if missing)';
    console.log(`  ${action} ${label} (${ref.path})`);
    return force ? 'overwritten' : 'created';
  }

  const exists = await docExists(ref);

  if (exists && !force) {
    console.log(`  SKIP  ${label} (${ref.path}) — already exists`);
    return 'skipped';
  }

  if (exists && force) {
    console.log(`  FORCE ${label} (${ref.path}) — overwriting`);
  } else {
    console.log(`  CREATE ${label} (${ref.path})`);
  }

  const payload = {
    ...data,
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (!exists) {
    payload.createdAt = FieldValue.serverTimestamp();
    await ref.set(payload);
  } else {
    const existing = (await ref.get()).data() || {};
    if (existing.createdAt) payload.createdAt = existing.createdAt;
    await ref.set(payload);
  }

  return exists && force ? 'overwritten' : 'created';
}

async function resolveAdminUid(auth) {
  if (process.env.ADMIN_UID) {
    return process.env.ADMIN_UID;
  }

  const email = process.env.ADMIN_EMAIL;
  const password = process.env.ADMIN_PASSWORD;

  if (!email) return null;

  try {
    const existing = await auth.getUserByEmail(email);
    console.log(`  Found Auth user for ${email} → ${existing.uid}`);
    return existing.uid;
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
  }

  if (!password) {
    console.warn(
      '  ADMIN_EMAIL set but user not found and ADMIN_PASSWORD missing — skipping user mapping.',
    );
    return null;
  }

  if (dryRun) {
    console.log(`  Would create Auth user: ${email}`);
    return 'dry-run-admin-uid';
  }

  const created = await auth.createUser({
    email,
    password,
    emailVerified: true,
    displayName: 'M4LIFE Admin',
  });
  console.log(`  Created Auth user ${email} → ${created.uid}`);
  return created.uid;
}

// ---------------------------------------------------------------------------
// Seed steps
// ---------------------------------------------------------------------------

async function run() {
  console.log('\nHitLook seed');
  console.log(`  dry-run: ${dryRun}`);
  console.log(`  force:   ${force}\n`);

  if (dryRun) {
    console.log(`Target project: ${DEFAULTS.projectId} (dry-run — no Firebase connection)\n`);
  }

  if (!dryRun) initFirebase();

  const db = dryRun ? null : admin.firestore();
  const auth = dryRun ? null : admin.auth();

  const { tenantId, companyId, sellerId, sellerSlug } = DEFAULTS;
  const stats = { created: 0, skipped: 0, overwritten: 0 };

  const paths = {
    tenant: `tenants/${tenantId}`,
    company: `companies/${companyId}`,
    seller: `companies/${companyId}/sellers/${sellerId}`,
    slug: `seller_slugs/${sellerSlug}`,
    user: (uid) => `users/${uid}`,
  };

  const ref = (docPath) =>
    dryRun ? { path: docPath } : db.doc(docPath);

  function tally(result) {
    if (result === 'created') stats.created++;
    else if (result === 'skipped') stats.skipped++;
    else if (result === 'overwritten') stats.overwritten++;
  }

  // 1. Tenant
  console.log('1. Tenant');
  tally(await safeSet(ref(paths.tenant), TENANT, `tenant:${tenantId}`));

  // 2. Company
  console.log('\n2. Company');
  tally(await safeSet(ref(paths.company), COMPANY, `company:${companyId}`));

  // 3. Admin UID (optional)
  console.log('\n3. Admin user (optional)');
  const adminUid = dryRun
    ? process.env.ADMIN_UID || (process.env.ADMIN_EMAIL ? 'dry-run-admin-uid' : null)
    : await resolveAdminUid(auth);
  const sellerUserId = adminUid && adminUid !== 'dry-run-admin-uid' ? adminUid : null;

  // 4. Seller profile
  console.log('\n4. Seller profile');
  const sellerData = {
    ...SELLER,
    companyId,
    slug: sellerSlug,
    ...(sellerUserId ? { userId: sellerUserId } : {}),
  };
  tally(await safeSet(ref(paths.seller), sellerData, `seller:${sellerId}`));

  // 5. Slug index (public /a/:slug)
  console.log('\n5. Seller slug');
  tally(
    await safeSet(
      ref(paths.slug),
      { companyId, sellerId, slug: sellerSlug },
      `seller_slug:${sellerSlug}`,
    ),
  );

  // 6. User mapping
  if (adminUid) {
    console.log('\n6. User document (admin)');
    if (adminUid === 'dry-run-admin-uid') {
      console.log(`  Would link users/dry-run-admin-uid → admin + seller`);
    } else {
      tally(
        await safeSet(
          ref(paths.user(adminUid)),
          {
            email: process.env.ADMIN_EMAIL || SELLER.email,
            displayName: 'M4LIFE Admin',
            tenantId,
            companyId,
            sellerId,
            role: 'admin',
          },
          `user:${adminUid}`,
        ),
      );

      if (!dryRun) {
        await ref(paths.seller).set(
          { userId: adminUid, updatedAt: FieldValue.serverTimestamp() },
          { merge: true },
        );
        console.log(`  Linked seller ${sellerId} → userId ${adminUid}`);
      }
    }
  } else {
    console.log('\n6. User document — skipped (set ADMIN_UID or ADMIN_EMAIL)');
  }

  // Summary
  console.log('\n--- Summary ---');
  console.log(`  created:     ${stats.created}`);
  console.log(`  skipped:     ${stats.skipped}`);
  console.log(`  overwritten: ${stats.overwritten}`);
  if (dryRun) console.log('\n(dry-run: no writes were made)\n');

  console.log('\nPublic lead form URL (web):');
  console.log(`  /a/${sellerSlug}`);
  console.log('\nFirestore paths:');
  console.log(`  tenants/${tenantId}`);
  console.log(`  companies/${companyId}`);
  console.log(`  companies/${companyId}/sellers/${sellerId}`);
  console.log(`  seller_slugs/${sellerSlug}`);
  if (adminUid && adminUid !== 'dry-run-admin-uid') {
    console.log(`  users/${adminUid}`);
  }
  console.log('');
}

run().catch((err) => {
  console.error('\nSeed failed:', err.message || err);
  process.exit(1);
});
