# 🤖 Stack de IA — Grupo DDM

> Documentação técnica do ecossistema de automação, IA e atendimento do Time de IA do Grupo DDM.

---

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Infraestrutura](#infraestrutura)
- [Serviços e Componentes](#serviços-e-componentes)
  - [Chatwoot](#chatwoot)
  - [WAHA / MeuChatIA](#waha--meuchatia)
  - [n8n](#n8n)
  - [frontCHAT](#frontchat)
  - [CallOps DDM](#callops-ddm)
- [Fluxos Principais](#fluxos-principais)
- [Variáveis de Ambiente](#variáveis-de-ambiente)
- [Repositórios](#repositórios)
- [Troubleshooting](#troubleshooting)

---

## Visão Geral

O stack de IA do Grupo DDM integra atendimento via WhatsApp, automações, disparos em massa e chamadas de voz com IA, centralizando tudo no Chatwoot como plataforma de atendimento omnichannel.

```
WhatsApp ↔ WAHA (MeuChatIA) ↔ Chatwoot
                                   ↑
                               n8n (automações)
                                   ↑
                          frontCHAT (dashboard)
                                   
Devedores → CallOps DDM → Vapi AI → Chamada de Voz
```

---

## Infraestrutura

| Plataforma | URL | Uso |
|---|---|---|
| Easypanel | `xzz0ed.easypanel.host` | Hospedagem dos containers |
| Railway | — | frontCHAT e CallOps |
| MeuChatIA | `api.meuchatia.com.br` | WAHA gerenciado |

### Containers no Easypanel (projeto `chatwoot_n8n`)

| Serviço | Tipo | Status |
|---|---|---|
| `chatwoot` | App (Rails + Sidekiq via Foreman) | ✅ Ativo |
| `postgres` | Banco de dados PostgreSQL | ✅ Ativo |
| `redis` | Cache e filas Sidekiq | ✅ Ativo |

> **Atenção:** o limite é 3 containers. O Sidekiq roda dentro do container `chatwoot` via `foreman` usando o `Procfile.prod`.

---

## Serviços e Componentes

### Chatwoot

Plataforma de atendimento omnichannel self-hosted. Fork customizado com branding DDM e uma rota extra para compatibilidade com WAHA.

**URL:** `https://chatwoot-n8n-chatwoot.xzz0ed.easypanel.host`  
**Login:** `admin@ddm.ia.br`  
**Repositório:** `github.com/Caio-Rodrigues-V/chatwoot` (branch `sync/fazer-ai`)  
**Versão:** 4.14.0 (fork do Fazer.ai)

**Inbox principal:**
- Nome: `Comercial - DDM`
- Tipo: `Channel::Api`
- Inbox ID: `5`
- Identifier: `APtfkzcStHRyzX7N8AZ3Lhnr`

**Customizações no fork:**
- `app/controllers/api/v1/accounts/inbox_messages_controller.rb` — rota customizada para receber mensagens do WAHA (inexistente no Chatwoot v4)
- `config/routes.rb` — rota `POST /api/v1/accounts/:account_id/inboxes/:inbox_id/messages`
- `Procfile.prod` — roda web + Sidekiq juntos via Foreman
- `Dockerfile` — CMD aponta para `Procfile.prod`

**Banco de dados:** `chatwoot_production` no container `postgres`

**Comandos úteis no banco:**
```sql
-- Listar inboxes
SELECT id, name FROM inboxes;

-- Verificar webhook da inbox
SELECT webhook_url FROM channel_api WHERE id = 4;

-- Resetar senha de admin
UPDATE users SET encrypted_password = 'HASH_BCRYPT' WHERE email = 'admin@ddm.ia.br';
```

---

### WAHA / MeuChatIA

Provedor gerenciado de WhatsApp via protocolo Baileys.

**Dashboard:** `https://api.meuchatia.com.br/dashboard/`  
**Sessão ativa:** `Comercialddm`  
**Número:** `5521999018751` (DDM COMERCIAL)

**App Chatwoot configurado na sessão:**
- App ID: `app_e1014ff34e8f42f6a30ab266e45c78c5`
- Account ID: `2`
- Account Token: `uzyPh18QkaW1PKqfcNskSzAF`
- Inbox ID: `5`
- Inbox Identifier: `APtfkzcStHRyzX7N8AZ3Lhnr`

**Webhook de entrada (WAHA → Chatwoot):**
```
URL: https://chatwoot-n8n-chatwoot.xzz0ed.easypanel.host/api/v1/accounts/2/inboxes/5/messages
Header: api_access_token: uzyPh18QkaW1PKqfcNskSzAF
Eventos: message, session.status
```

**Webhook de saída (Chatwoot → WAHA):**
```
URL: https://api.meuchatia.com.br/webhooks/chatwoot/Comercialddm/app_e1014ff34e8f42f6a30ab266e45c78c5
Configurado em: channel_api.webhook_url (banco, id=4)
```

**Anti-ban guidelines:**
- Até 200 disparos/dia a 3s de intervalo: seguro
- Acima de 1000/dia: necessário múltiplos números

---

### n8n

Plataforma de automação de workflows.

**URL:** `https://n8n.grupoddm.ia.br`  
**Container:** projeto separado no Easypanel (`n8n-start`)

**Workflows principais:**
- `Disparo DDM — WhatsApp + Chatwoot` — disparo em massa via form webhook, aceita template com `{nome}`/`{telefone}`, upload de Excel/CSV, envia via WAHA com delay de 3s e cria contatos/conversas no Chatwoot
- `Prestação de Contas - Email` — monitora IMAP para emails de prestação de contas entre domínios DDM

**Variáveis de ambiente relevantes:**
- `OPENAI_API_KEY` — para randomização de mensagens via GPT-4o-mini
- Credenciais WAHA, Chatwoot configuradas nos nodes

> **Status:** o n8n foi desconectado do fluxo WhatsApp → Chatwoot. A integração agora é direta via app nativo do MeuChatIA.

---

### frontCHAT

Dashboard de gerenciamento de campanhas WhatsApp.

**URL:** `https://frontchat-production-5d38.up.railway.app`  
**Repositório:** Railway + GitHub  
**Stack:** React 18 + Vite + Tailwind

**Funcionalidades implementadas:**
- Disparo de campanhas via n8n (webhook)
- KPIs em tempo real via Chatwoot API
- Upload de lista de contatos (Excel/CSV)

**Pendências:**
- Histórico de campanhas via Google Sheets
- Randomização de mensagens via OpenAI GPT-4o-mini
- Toggle multi-número WAHA
- Autenticação do dashboard
- Vinculação do Agente DDM (Groq/Llama 3) ao Chatwoot

---

### CallOps DDM

Sistema de ligações automáticas com IA para cobrança.

**Plataforma:** Railway (Flask/Gunicorn + Celery)  
**Stack:** Python, Vapi AI, Wavoip SIP, Supabase, API DDM Acordos

**Fluxo:**
1. Importa planilha de devedores
2. Consulta dívida via `CalculaDebitos.php` (API DDM)
3. Dispara ligação via Vapi AI → Wavoip SIP
4. Registra resultado no Supabase

**Status:** ~85% completo. Pendente: restrição SIP por instituição, testes end-to-end com números Vapi reais, otimização de filas.

---

## Fluxos Principais

### Recebimento de mensagem (WhatsApp → Chatwoot)

```
1. Usuário envia mensagem no WhatsApp
2. WAHA (MeuChatIA) captura e envia POST para:
   /api/v1/accounts/2/inboxes/5/messages
3. InboxMessagesController (customizado) processa:
   - Extrai telefone de payload._data.Info.SenderAlt
   - Cria/encontra Contact com phone_number
   - Cria/encontra ContactInbox com source_id = "número@c.us"
   - Cria/encontra Conversation aberta
   - Cria Message incoming
4. Chatwoot exibe na inbox "Comercial - DDM"
```

### Envio de mensagem (Chatwoot → WhatsApp)

```
1. Agente envia mensagem pelo Chatwoot
2. Sidekiq enfileira WebhookJob
3. WebhookJob faz POST para:
   https://api.meuchatia.com.br/webhooks/chatwoot/Comercialddm/app_e1014ff34e8f42f6a30ab266e45c78c5
4. MeuChatIA recebe evento e envia via WAHA para o número do contato
   (identificado pelo source_id: "número@c.us")
```

### Disparo em massa

```
1. Operador acessa frontCHAT
2. Faz upload de lista Excel/CSV
3. frontCHAT dispara webhook no n8n
4. n8n itera lista com delay de 3s:
   - Envia mensagem via WAHA
   - Cria contato e conversa no Chatwoot
```

---

## Variáveis de Ambiente

### Chatwoot (Easypanel)

| Variável | Descrição |
|---|---|
| `DATABASE_URL` | URL de conexão PostgreSQL |
| `REDIS_URL` | URL do Redis |
| `SECRET_KEY_BASE` | Chave secreta Rails |
| `RAILS_ENV` | `production` |

### n8n

| Variável | Descrição |
|---|---|
| `OPENAI_API_KEY` | API da OpenAI para GPT-4o-mini |

---

## Repositórios

| Projeto | Repositório | Branch |
|---|---|---|
| Chatwoot (fork DDM) | `github.com/Caio-Rodrigues-V/chatwoot` | `sync/fazer-ai` |
| frontCHAT | Railway/GitHub | `main` |
| CallOps DDM | Railway | — |

---

## Troubleshooting

### Inboxes duplicadas aparecem no Chatwoot

O Sidekiq estava ausente, fazendo jobs de exclusão ficarem presos. Com o Foreman rodando, a exclusão via UI funciona normalmente.

Se necessário, deletar direto no banco:
```sql
\c chatwoot_production
DELETE FROM inboxes WHERE id != 5;
```

### Mensagens não chegam no Chatwoot

1. Verificar se sessão `Comercialddm` está `WORKING` no MeuChatIA
2. Verificar se webhook aponta para a URL correta com o header `api_access_token`
3. Checar logs do container `chatwoot` no Easypanel

### Mensagens do agente não chegam no WhatsApp

1. Verificar `channel_api.webhook_url` no banco (deve ter a URL do MeuChatIA com app ID correto)
2. Verificar se `source_id` do `ContactInbox` está no formato `número@c.us`
3. Checar se o app Chatwoot está `ENABLED` na sessão do MeuChatIA

### Container Chatwoot cai em loop

Verificar o `Procfile.prod` — deve ter apenas `web` e `worker`, sem a entrada `release`.

### Login inválido no Chatwoot

Resetar senha via banco:
```bash
# No terminal do container chatwoot
bundle exec rails runner "puts BCrypt::Password.create('nova_senha')"

# No postgres
UPDATE users SET encrypted_password = 'HASH_GERADO' WHERE email = 'admin@ddm.ia.br';
```

---

*Documentação gerada em Junho/2026 — Time de IA, Grupo DDM*