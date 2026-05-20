# Trigger Email — notificação de novo lead

## Instalação (uma vez no Firebase Console)

1. [Firebase Console](https://console.firebase.google.com/project/hitlook-app/extensions) → **Extensions**
2. Instalar **Trigger Email from Firestore** (`firebase/firestore-send-email`)
3. Parâmetros sugeridos:
   - **Firestore Instance Location:** `nam5` (mesma do projeto)
   - **Collection path:** `mail`
   - **SMTP:** configurar SendGrid, Mailgun ou Gmail conforme o wizard
4. Após instalar, fazer deploy da função:

```bash
firebase deploy --only functions:notifyAgentOnNewLead,firestore:rules
```

## Fluxo

1. Prospect completa o fluxo → documento em `leads/{id}`
2. Cloud Function `notifyAgentOnNewLead` resolve o e-mail do agente (`users`, `agents` ou Auth)
3. Grava documento em `mail/{id}` com `to` + `message`
4. A extensão envia o e-mail automaticamente

## Conteúdo do e-mail

- Nome do prospect
- Telefone
- Score
- Idioma (PT / ES / EN)
