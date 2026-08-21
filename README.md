# Hermes Genial Care — Facilitador de Configuração

Scripts para configurar o **Hermes Agent** padrão da sua máquina com o setup da Genial Care — provider LLM, MCPs corporativos, browser connect, busca e Google Workspace.

## O que é

Este repositório **não distribui um profile**. Os scripts abaixo configuram o Hermes que você já usa no dia a dia (`~/.hermes`), ajustando `config.yaml` com `hermes config set` e adicionando MCPs com `hermes mcp add` — sempre pela CLI oficial, nunca editando arquivos à mão.

- Rodar de novo é seguro: os scripts são idempotentes.
- Você decide o que configurar: cada MCP e o Google Workspace são perguntados individualmente.
- Suas skills pessoais, memórias e sessões nunca são tocadas.

> Procurando a versão antiga (distribuição de profile)? Ela está preservada na branch [`profile-distribution`](https://github.com/GenialCare/hermes-profile-genial/tree/profile-distribution).

## Pré-requisitos

- **Hermes Agent instalado.** Baixe o Hermes Desktop em [hermes-agent.nousresearch.com](https://hermes-agent.nousresearch.com/) (macOS `.dmg`, Windows `.exe`) ou instale via terminal:
  - macOS/Linux: `curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash`
  - Windows (PowerShell): `iex (irm https://hermes-agent.nousresearch.com/install.ps1)`
- **Chave OpenRouter (obrigatória).** Solicite o convite (invite) com o **Matheus Cáceres** no canal **#construindo-com-ia** no Slack, antes de rodar o script. Sem a chave, o script para e não configura nada. Se você já tiver a variável `OPENROUTER_API_KEY` exportada no seu shell, o script a reaproveita automaticamente (não pede de novo).

Os scripts verificam se o Hermes está instalado e param com instruções caso não esteja — eles não instalam o Hermes por você.

## Como usar

Copie o comando do seu sistema, cole no Terminal/PowerShell e pressione Enter:

**macOS / Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/GenialCare/hermes-profile-genial/main/install-genial.sh | bash
```

**Windows (PowerShell)**

```powershell
iex (irm https://raw.githubusercontent.com/GenialCare/hermes-profile-genial/main/install-genial.ps1)
```

## O que o script configura

| Item | O que acontece |
| --- | --- |
| Modelo padrão | `anthropic/claude-sonnet-5` via OpenRouter |
| Tarefas auxiliares/delegação | `anthropic/claude-sonnet-5` via OpenRouter |
| MCPs corporativos | Baixa `mcp_servers.json` deste repo e configura os 4 de uma vez (Atlassian, Granola, Slack, Metabase), depois autentica cada um no browser |
| Browser | Conecta via CDP (Chrome com perfil isolado em `~/.hermes/chrome-debug`; login persiste) |
| Busca | Ativa o DuckDuckGo (`ddgs`) como backend de busca |
| Google Workspace | Pergunta se você usa; se sim, instala o `gws` CLI e orienta o `gws auth login`. Depois de autenticado, o script pode disparar automaticamente a configuração da skill no Hermes. No Windows, o script encontra o Node.js do Hermes automaticamente mesmo quando ele não está no PATH. |

Sua chave OpenRouter é salva em `~/.hermes/.env` (nunca commitada, nunca compartilhada).

## Google Workspace (Drive, Gmail, Calendar, Sheets, Docs)

O script instala o `gws` CLI e orienta a autenticação. O passo de `gws auth login` precisa ser feito por você (abre o browser), mas depois disso o script pode configurar a skill do Hermes automaticamente:

1. Acesse a página do Confluence (Parte 4 — link com a equipe/canal #construindo-com-ia).
2. Baixe o `client_secret.json` anexado à página.
3. Salve em `~/.config/gws/client_secret.json` (macOS/Linux) ou `%USERPROFILE%\.config\gws\client_secret.json` (Windows).
4. Rode `gws auth login`.
5. Quando o script perguntar se você já autenticou, responda "sim" — ele confere com `gws auth status` e, se estiver tudo certo, dispara automaticamente o mesmo comando que você enviaria manualmente ao Hermes (`/google-workspace eu já configurei o gws por fora, então configure a skill para utilizar essas credenciais no hermes`).

Se você preferir fazer esse último passo manualmente (ou se o script não conseguir), basta abrir o Hermes e enviar essa mensagem você mesmo.

## Idempotência e re-execução

Rodar o script de novo é seguro:
- Perguntas já respondidas com "não" voltam a ser perguntadas (você pode mudar de ideia).
- A chave OpenRouter é obrigatória apenas na primeira vez — não é pedida de novo se já existir no `.env`.
- MCPs já autenticados não perdem o token.
- `hermes profile update` **não se aplica** aqui — não existe profile.

## FAQ

- **Onde o Hermes guarda a chave OpenRouter:** em `~/.hermes/.env`, na variável `OPENROUTER_API_KEY`. O Hermes só lê credenciais desse arquivo — exportar a variável no `~/.zshrc` (como na Parte 1, para o Claude Code) não é suficiente para o Hermes, mas o script detecta e reaproveita automaticamente se a variável já estiver exportada na sua sessão de terminal.
- **Não tenho chave OpenRouter:** peça o convite (invite) com o Matheus Cáceres no canal `#construindo-com-ia`. O script exige a chave para continuar.
- **O script disse que a chave não foi informada, mas eu digitei:** rode um terminal atualizado — versões antigas do script (antes de 13/ago) tinham um bug em que `curl ... | bash` fazia o `read` da chave ler o próprio código do script em vez do teclado. Já corrigido; baixe o comando de novo do início desta página.
- **O login de um MCP falhou:** rode `hermes mcp login <nome>` (atlassian, granola, slack ou metabase).
- **Quero trocar o modelo:** `hermes config set model.default <modelo>` (ex.: `z-ai/glm-5.2`).
- **Quero ver o que está configurado:** `hermes config get model.default`, `hermes mcp list`.
- **Dúvidas:** canal `#construindo-com-ia` no Slack.

## Como contribuir

1. Crie uma branch a partir da `main`.
2. Faça suas mudanças nos scripts, README ou workflow.
3. Abra um PR com título em **Conventional Commits** (ex.: `fix(script): corrige detecção do Chrome no Linux`).
4. A CI valida automaticamente: mensagens de commit e título do PR devem seguir Conventional Commits (`feat, fix, docs, refactor, chore, test, perf, style, build, ci, revert`).
5. Antes de abrir o PR:
   - `bash -n install-genial.sh` (sintaxe válida)
   - Teste o fluxo com um `HERMES_HOME` temporário — veja `SKIP_MCP_LOGIN=1` e `SKIP_BROWSER=1` no início do script para pular etapas interativas durante testes
   - Mudanças em `install-genial.ps1` precisam ser testadas em uma máquina Windows real antes do merge

Veja `AGENTS.md` para as regras completas de contribuição.
