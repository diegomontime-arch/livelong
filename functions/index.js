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
