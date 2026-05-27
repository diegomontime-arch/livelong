const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const https = require("https");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Anthropic API key — Secret Manager (replaces deprecated functions.config()).
// Set via: firebase functions:secrets:set ANTHROPIC_API_KEY
// See planning/SECURITY.md S9 and planning/FUNCTIONS_AUDIT.md §F2/§F9.
const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

// Origin allowlist for the anthropicProxy fallback function (paranoia
// in addition to App Check). See planning/SECURITY.md S7.
const ANTHROPIC_PROXY_ALLOWED_ORIGINS = new Set([
  "https://hitlook-app.web.app",
  "https://hitlook-app.firebaseapp.com",
  "http://localhost:8080",
]);

exports.anthropicProxy = onRequest(
  {
    region: "us-central1",
    secrets: [ANTHROPIC_API_KEY],
    cors: false, // we handle CORS manually with the allowlist below
  },
  (req, res) => {
    const origin = req.headers.origin || "";
    const corsOrigin = ANTHROPIC_PROXY_ALLOWED_ORIGINS.has(origin)
      ? origin
      : "null";

    res.set("Access-Control-Allow-Origin", corsOrigin);
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.set("Vary", "Origin");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    if (!ANTHROPIC_PROXY_ALLOWED_ORIGINS.has(origin)) {
      logger.warn("anthropicProxy rejected origin", { origin });
      res.status(403).json({ error: "Forbidden" });
      return;
    }

    const apiKey = ANTHROPIC_API_KEY.value();
    if (!apiKey) {
      logger.error("anthropicProxy: ANTHROPIC_API_KEY not configured");
      res.status(500).json({ error: "Not configured" });
      return;
    }

    const body = JSON.stringify(req.body);

    const options = {
      hostname: "api.anthropic.com",
      path: "/v1/messages",
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "Content-Length": Buffer.byteLength(body),
      },
      timeout: 30_000,
    };

    const proxyReq = https.request(options, (proxyRes) => {
      let data = "";
      proxyRes.on("data", (chunk) => (data += chunk));
      proxyRes.on("end", () => {
        res.status(proxyRes.statusCode).send(data);
      });
    });

    proxyReq.on("timeout", () => {
      proxyReq.destroy(new Error("Anthropic upstream timeout"));
    });

    proxyReq.on("error", (e) => {
      logger.error("anthropicProxy upstream error", e);
      res.status(502).json({ error: e.message });
    });

    proxyReq.write(body);
    proxyReq.end();
  },
);

const LANG_LABEL = { pt: "Português", es: "Español", en: "English" };

// Localized strings for the lead notification email (planning B6).
// Keys: pt (default + pt-br), es, en. Falls back to pt if unknown.
const EMAIL_I18N = {
  pt: {
    subject: (nome) => `Novo lead HitLook: ${nome}`,
    heading: "Novo lead HitLook",
    fields: {
      nome: "Nome",
      telefone: "Telefone",
      score: "Score",
      idioma: "Idioma",
    },
    intro: "Você recebeu um novo lead no HitLook.",
    cta: "Acesse seu painel:",
    ctaLink: "Abrir painel",
    disclaimer:
      "HitLook é uma ferramenta educacional. Recomendações de seguros devem partir do agente licenciado.",
  },
  es: {
    subject: (nome) => `Nuevo lead HitLook: ${nome}`,
    heading: "Nuevo lead HitLook",
    fields: {
      nome: "Nombre",
      telefone: "Teléfono",
      score: "Score",
      idioma: "Idioma",
    },
    intro: "Has recibido un nuevo lead en HitLook.",
    cta: "Accede a tu panel:",
    ctaLink: "Abrir panel",
    disclaimer:
      "HitLook es una herramienta educativa. Las recomendaciones de seguros deben provenir del agente licenciado.",
  },
  en: {
    subject: (nome) => `New HitLook lead: ${nome}`,
    heading: "New HitLook lead",
    fields: {
      nome: "Name",
      telefone: "Phone",
      score: "Score",
      idioma: "Language",
    },
    intro: "You have a new lead on HitLook.",
    cta: "Open your dashboard:",
    ctaLink: "Open dashboard",
    disclaimer:
      "HitLook is an educational tool. Insurance recommendations must come from the licensed agent.",
  },
};

function resolveEmailLang(lead) {
  const raw = (lead && (lead.lang || lead.locale) || "").toString().toLowerCase();
  if (raw.startsWith("es")) return "es";
  if (raw.startsWith("en")) return "en";
  if (raw.startsWith("pt")) return "pt";
  return "pt";
}

/**
 * Admin creates seller Auth account + returns uid (password set server-side).
 */
exports.createSellerAccount = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const callerDoc = await db.collection("users").doc(request.auth.uid).get();
    if (!callerDoc.exists || callerDoc.data().role !== "admin") {
      throw new HttpsError("permission-denied", "Admin only");
    }

    const { email, password, displayName, companyId, sellerId } = request.data || {};
    if (!email || !password || !displayName || !companyId || !sellerId) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    try {
      const user = await admin.auth().createUser({
        email: String(email).trim(),
        password: String(password),
        displayName: String(displayName).trim(),
      });

      await db.collection("users").doc(user.uid).set(
        {
          email: String(email).trim(),
          displayName: String(displayName).trim(),
          role: "seller",
          companyId: String(companyId),
          sellerId: String(sellerId),
          mustChangePassword: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      logger.info("createSellerAccount OK", { uid: user.uid, companyId, sellerId });
      return { uid: user.uid };
    } catch (e) {
      logger.error("createSellerAccount failed", e);
      throw new HttpsError("internal", e.message || "Failed to create user");
    }
  },
);

/**
 * Queues email via Firebase Extension "Trigger Email from Firestore" (`mail`).
 */
exports.notifyAgentOnNewLead = onDocumentCreated(
  { document: "leads/{leadId}", region: "us-central1" },
  async (event) => {
  const snap = event.data;
  if (!snap) return;

  const lead = snap.data();
  const agentId = lead.agentId;
  if (!agentId) {
    logger.warn("Lead without agentId", event.params.leadId);
    return;
  }

  const email = await resolveAgentEmail(agentId);
  if (!email) {
    logger.warn("No email for agent", agentId);
    return;
  }

  const nome = lead.nome || "Prospect";
  const telefone = lead.telefone || "—";
  const score = lead.score != null ? `${lead.score}%` : "—";
  const lang = LANG_LABEL[lead.lang] || lead.lang || "—";

  const langKey = resolveEmailLang(lead);
  const t = EMAIL_I18N[langKey];
  const dashboardUrl = "https://hitlook-app.web.app/dashboard";

  const subject = t.subject(nome);
  const text =
    `${t.intro}\n\n` +
    `${t.fields.nome}: ${nome}\n` +
    `${t.fields.telefone}: ${telefone}\n` +
    `${t.fields.score}: ${score}\n` +
    `${t.fields.idioma}: ${lang}\n\n` +
    `${t.cta} ${dashboardUrl}\n\n` +
    `— ${t.disclaimer}`;

  const html =
    `<h2>${escapeHtml(t.heading)}</h2>` +
    `<p><strong>${escapeHtml(t.fields.nome)}:</strong> ${escapeHtml(nome)}</p>` +
    `<p><strong>${escapeHtml(t.fields.telefone)}:</strong> ${escapeHtml(telefone)}</p>` +
    `<p><strong>${escapeHtml(t.fields.score)}:</strong> ${escapeHtml(String(score))}</p>` +
    `<p><strong>${escapeHtml(t.fields.idioma)}:</strong> ${escapeHtml(lang)}</p>` +
    `<p><a href="${dashboardUrl}">${escapeHtml(t.ctaLink)}</a></p>` +
    `<hr><p style="font-size:12px;color:#666">${escapeHtml(t.disclaimer)}</p>`;

  await db.collection("mail").add({
    to: email,
    message: { subject, text, html },
  });

  logger.info("Queued lead email", { leadId: event.params.leadId, to: email });
  },
);

async function resolveAgentEmail(agentId) {
  const userDoc = await db.collection("users").doc(agentId).get();
  if (userDoc.exists) {
    const email = userDoc.data().email;
    if (email) return email;
  }

  const agentDoc = await db.collection("agents").doc(agentId).get();
  if (agentDoc.exists) {
    const data = agentDoc.data();
    if (data.email) return data.email;
    const uid = data.userId;
    if (uid) {
      const u = await db.collection("users").doc(uid).get();
      if (u.exists && u.data().email) return u.data().email;
    }
  }

  try {
    const authUser = await admin.auth().getUser(agentId);
    if (authUser.email) return authUser.email;
  } catch (_) {
    // not a Firebase Auth uid
  }

  return null;
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

const crypto = require("crypto");

/**
 * Self-service account deletion (CCPA §1798.105 / Apple Guideline 5.1.1(v)).
 *
 * Hybrid model (decision 2026-05-24):
 *   - Agent's PII (name, photo, bio, phone, email) is removed.
 *   - Seller document stays in Firestore as anonymized "Ex-agente" so
 *     the tenant admin (Renan) keeps historical lead attribution.
 *   - Firebase Auth user is deleted (so password reset stops working).
 *   - Storage photo file is deleted.
 *   - `seller_slugs/{slug}` is marked deactivated to block new leads.
 *   - Public link /a/{slug} starts 404-ing because the legacy mirror is gone.
 *   - Audit log in `accountDeletions/{hashedUid}` for 3-year compliance trail.
 *
 * Re-auth is enforced at the client (Firebase Auth requires recent login
 * to call Auth.deleteUser).
 */
exports.deleteAgentAccount = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const uid = request.auth.uid;

    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found");
    }
    const user = userSnap.data();
    const role = user.role;
    const companyId = user.companyId;
    const sellerId = user.sellerId;

    if (role !== "seller") {
      // Admins cannot self-delete via this function — Diego/Renan would
      // wipe critical state. Force a manual / support flow instead.
      throw new HttpsError(
        "failed-precondition",
        "Admin accounts must be deleted by HitLook support — contact privacy@hitlook.us",
      );
    }
    if (!companyId || !sellerId) {
      throw new HttpsError(
        "failed-precondition",
        "Account is missing companyId/sellerId — contact support",
      );
    }

    const sellerRef = db
      .collection("companies").doc(companyId)
      .collection("sellers").doc(sellerId);
    const sellerSnap = await sellerRef.get();
    if (!sellerSnap.exists) {
      throw new HttpsError("not-found", "Seller not found");
    }
    const seller = sellerSnap.data();
    const slug = seller.slug;

    // ── 1. Anonymize seller doc — keep ID + slug for historical leads ──
    await sellerRef.set(
      {
        displayName: "Ex-agente",
        photoUrl: null,
        bio: null,
        phone: null,
        email: null,
        instagramUrl: null,
        linkedinUrl: null,
        isActive: false,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    // ── 2. Deactivate slug index (public link 404s) ──
    if (slug) {
      await db.collection("seller_slugs").doc(slug).set(
        {
          deactivated: true,
          deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    // ── 3. Delete legacy /agents mirrors ──
    const agentsBatch = db.batch();
    agentsBatch.delete(db.collection("agents").doc(uid));
    if (slug) agentsBatch.delete(db.collection("agents").doc(slug));
    await agentsBatch.commit().catch((e) => {
      logger.warn("agents/* delete partial fail", e.message);
    });

    // ── 4. Delete Storage photo ──
    try {
      const bucket = admin.storage().bucket();
      await bucket.file(`agents/${uid}/photo`).delete({ ignoreNotFound: true });
    } catch (e) {
      logger.warn("storage photo delete fail", e.message);
    }

    // ── 5. Audit log (hashed uid, 3-year retention by FL/CCPA practice) ──
    const hashedUid = crypto.createHash("sha256").update(uid).digest("hex");
    await db.collection("accountDeletions").doc(hashedUid).set({
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      companyId,
      sellerId,
      slug: slug || null,
      mode: "hybrid",
    });

    // ── 6. Delete users/{uid} doc ──
    await db.collection("users").doc(uid).delete();

    // ── 7. Finally delete the Firebase Auth user ──
    try {
      await admin.auth().deleteUser(uid);
    } catch (e) {
      logger.error("auth deleteUser failed", { uid, message: e.message });
      // Don't rethrow — Firestore state already consistent; the user
      // can re-login (but companyId/sellerId are gone, so they get
      // bounced to login). Support cleans up the Auth user later.
    }

    logger.info("deleteAgentAccount OK", { uidHash: hashedUid.slice(0, 12) });
    return { success: true, mode: "hybrid" };
  },
);
