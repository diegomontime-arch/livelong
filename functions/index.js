const functions = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
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
