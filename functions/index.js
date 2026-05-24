const functions = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const https = require("https");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

exports.anthropicProxy = functions.https.onRequest((req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const apiKey = functions.config().anthropic?.key;
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
  };

  const proxyReq = https.request(options, (proxyRes) => {
    let data = "";
    proxyRes.on("data", (chunk) => (data += chunk));
    proxyRes.on("end", () => {
      res.status(proxyRes.statusCode).send(data);
    });
  });

  proxyReq.on("error", (e) => {
    res.status(500).send({ error: e.message });
  });

  proxyReq.write(body);
  proxyReq.end();
});

const LANG_LABEL = { pt: "Português", es: "Español", en: "English" };

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

  const subject = `Novo lead HitLook: ${nome}`;
  const text =
    `Você recebeu um novo lead no HitLook.\n\n` +
    `Nome: ${nome}\n` +
    `Telefone: ${telefone}\n` +
    `Score: ${score}\n` +
    `Idioma: ${lang}\n\n` +
    `Acesse seu painel: https://hitlook-app.web.app/dashboard`;

  const html =
    `<h2>Novo lead HitLook</h2>` +
    `<p><strong>Nome:</strong> ${escapeHtml(nome)}</p>` +
    `<p><strong>Telefone:</strong> ${escapeHtml(telefone)}</p>` +
    `<p><strong>Score:</strong> ${escapeHtml(String(score))}</p>` +
    `<p><strong>Idioma:</strong> ${escapeHtml(lang)}</p>` +
    `<p><a href="https://hitlook-app.web.app/dashboard">Abrir painel</a></p>`;

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
