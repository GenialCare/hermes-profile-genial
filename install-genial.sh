#!/usr/bin/env bash
# ============================================================================
# Facilitador de Configuração do Hermes — Genial Care
# macOS / Linux
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/GenialCare/hermes-profile-genial/main/install-genial.sh | bash
#
# O que faz (NÃO cria profile — configura o Hermes PADRÃO da sua máquina):
#   1. Verifica se o Hermes está instalado (se não, orienta a instalar e para)
#   2. Configura o provider LLM (Claude Sonnet 5 via OpenRouter)
#   3. Pergunta, um a um, quais MCPs corporativos você usa e autentica só esses
#   4. Conecta o browser via CDP (Chrome com perfil isolado, login persiste)
#   5. Ativa a busca DuckDuckGo
#   6. Pergunta se você usa Google Workspace e instala o gws CLI (a autenticação
#      é feita separadamente, seguindo a Parte 4 da documentação no Confluence)
#
# Idempotente: pode rodar de novo sem duplicar nada.
# ============================================================================
set -euo pipefail

HERMES_HOME_DIR="${HERMES_HOME:-$HOME/.hermes}"

say()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m==>\033[0m %s\n' "$*"; }
err()  { printf '\n\033[1;31m==>\033[0m %s\n' "$*"; }

ask_yes() { # $1 = pergunta; retorna 0 (sim) ou 1 (não)
  local resp resp_lower
  read -r -p "$1 [s/N] " resp
  resp_lower=$(printf '%s' "$resp" | tr '[:upper:]' '[:lower:]')
  [[ "$resp_lower" =~ ^(s|sim|y|yes)$ ]]
}

# ----------------------------------------------------------------------------
# 1. Hermes instalado?
# ----------------------------------------------------------------------------
if ! command -v hermes >/dev/null 2>&1; then
  err "Hermes não está instalado."
  say "Instale primeiro e depois rode este script de novo:"
  echo "  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"
  exit 1
fi

say "Hermes encontrado: $(command -v hermes)"

# ----------------------------------------------------------------------------
# 2. Provider LLM padrão (Claude Sonnet 5 via OpenRouter)
# ----------------------------------------------------------------------------
say "Configurando provider LLM (Claude Sonnet 5 via OpenRouter)..."
hermes config set model.default anthropic/claude-sonnet-5
hermes config set model.provider openrouter
hermes config set model.base_url https://openrouter.ai/api/v1
hermes config set model.api_mode chat_completions
hermes config set auxiliary.skills_hub.provider openrouter
hermes config set auxiliary.skills_hub.model deepseek/deepseek-v4-pro
hermes config set delegation.model deepseek/deepseek-v4-pro
hermes config set delegation.provider openrouter

# Chave OpenRouter
ENV_FILE="$HERMES_HOME_DIR/.env"
if ! grep -q '^OPENROUTER_API_KEY=.' "$ENV_FILE" 2>/dev/null; then
  read -rsp "Cole sua chave OpenRouter (sk-or-...) e pressione Enter: " KEY
  echo
  if [[ -n "${KEY:-}" ]]; then
    echo "OPENROUTER_API_KEY=$KEY" >> "$ENV_FILE"
    say "Chave salva em $ENV_FILE"
  else
    warn "Sem chave agora? Adicione depois em $ENV_FILE (ou exporte OPENROUTER_API_KEY)."
  fi
else
  say "Chave OpenRouter já configurada."
fi

# ----------------------------------------------------------------------------
# 3. MCPs corporativos — um a um, só se a pessoa usar
# ----------------------------------------------------------------------------
MCP_ATLASSIAN_URL="https://mcp.atlassian.com/v1/mcp"
MCP_GRANOLA_URL="https://mcp.granola.ai/mcp"
MCP_SLACK_URL="https://mcp.slack.com/mcp"
MCP_METABASE_URL="https://analytics-panel.genialcare.com.br/api/mcp"

setup_mcp() { # $1=nome $2=url
  local name="$1" url="$2"
  if ask_yes "Você usa o MCP $name?"; then
    say "Configurando MCP $name..."
    hermes mcp add "$name" --url "$url" --auth oauth
    case "$name" in
      slack)
        # client_id contém um ponto entre dígitos (ex.: 123.456) — "hermes config set"
        # faz parse numérico do valor e TRUNCA para float, corrompendo o client_id.
        # Editamos o YAML diretamente com o Python do venv do Hermes (sempre tem
        # PyYAML, pois é dependência do próprio Hermes) para garantir que o valor
        # seja gravado como string.
        PYBIN="$HERMES_HOME_DIR/hermes-agent/venv/bin/python"
        if [[ -x "$PYBIN" ]]; then
          "$PYBIN" - "$HERMES_HOME_DIR/config.yaml" <<'PYEOF'
import sys, yaml
path = sys.argv[1]
with open(path) as f:
    data = yaml.safe_load(f) or {}
data.setdefault("mcp_servers", {}).setdefault("slack", {}).setdefault("oauth", {})["client_id"] = "1451718280373.11571103729251"
with open(path, "w") as f:
    yaml.safe_dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
PYEOF
        else
          warn "Não encontrei o Python do Hermes em $PYBIN. Configure manualmente em $HERMES_HOME_DIR/config.yaml:"
          echo "    mcp_servers.slack.oauth.client_id (como STRING, entre aspas) = '1451718280373.11571103729251'"
        fi
        hermes config set mcp_servers.slack.oauth.redirect_port 8932
        ;;
      metabase)
        hermes config set mcp_servers.metabase.headers.User-Agent 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        ;;
    esac
    say "Autenticando $name (abre o browser)..."
    if [[ -n "${SKIP_MCP_LOGIN:-}" ]]; then
      warn "SKIP_MCP_LOGIN=1: pulando o login de $name (modo de teste)."
    else
      hermes mcp login "$name" || warn "Falha no login de $name. Repita depois: hermes mcp login $name"
    fi
  else
    say "Pulando $name."
  fi
}

say "Vamos configurar os MCPs corporativos. Responda apenas os que você usa."
setup_mcp atlassian "$MCP_ATLASSIAN_URL"
setup_mcp granola   "$MCP_GRANOLA_URL"
setup_mcp slack     "$MCP_SLACK_URL"
setup_mcp metabase  "$MCP_METABASE_URL"

# ----------------------------------------------------------------------------
# 4. Browser connect (CDP)
# ----------------------------------------------------------------------------
say "Configurando conexão com o browser (CDP)..."
hermes config set browser.cdp_url http://127.0.0.1:9222

if [[ -n "${SKIP_BROWSER:-}" ]]; then
  warn "SKIP_BROWSER=1: pulando a abertura do Chrome (modo de teste)."
elif ! curl -fsS http://127.0.0.1:9222/json/version >/dev/null 2>&1; then
  say "Abrindo Chrome com depuração remota (perfil isolado em ~/.hermes/chrome-debug)..."
  CHROME=""
  case "$(uname)" in
    Darwin) CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ;;
    Linux)  CHROME="$(command -v google-chrome || command -v google-chrome-stable || command -v chromium || command -v chromium-browser || true)" ;;
  esac
  if [[ -n "$CHROME" && -e "$CHROME" ]] || command -v "$CHROME" >/dev/null 2>&1; then
    "$CHROME" --remote-debugging-port=9222 \
      --user-data-dir="$HERMES_HOME_DIR/chrome-debug" \
      --no-first-run --no-default-browser-check >/dev/null 2>&1 &
    disown
    sleep 3
  else
    warn "Chrome não encontrado automaticamente. Abra o Chrome manualmente com:"
    echo "  google-chrome --remote-debugging-port=9222 --user-data-dir=$HERMES_HOME_DIR/chrome-debug"
    echo "e depois rode /browser connect dentro do Hermes."
  fi
else
  say "Chrome já está respondendo na porta 9222."
fi
say "Browser conectado via CDP em 127.0.0.1:9222. Faça login uma vez na janela do Chrome — ele persiste entre sessões."

# ----------------------------------------------------------------------------
# 5. Busca DuckDuckGo
# ----------------------------------------------------------------------------
say "Configurando busca DuckDuckGo..."
hermes tools post-setup ddgs || warn "Não consegui instalar o ddgs automaticamente. Rode depois: hermes tools post-setup ddgs"
hermes config set web.search_backend ddgs

# ----------------------------------------------------------------------------
# 6. Google Workspace (gws) — opcional, sem autenticar automaticamente
# ----------------------------------------------------------------------------
if ask_yes "Você usa Google Workspace (Drive, Gmail, Calendar, Sheets, Docs)?"; then
  if ! command -v gws >/dev/null 2>&1; then
    say "Instalando o gws CLI..."
    if command -v brew >/dev/null 2>&1; then
      brew install googleworkspace-cli
    elif command -v npm >/dev/null 2>&1; then
      npm install -g @googleworkspace/cli
    else
      warn "Nem Homebrew nem npm encontrados."
      echo "  Baixe o binário em https://github.com/googleworkspace/cli/releases e coloque no PATH."
    fi
  else
    say "gws já está instalado."
  fi

  if command -v gws >/dev/null 2>&1; then
    say "gws instalado. Para autenticar, siga a documentação no Confluence (Parte 4) —"
    echo "  lá você encontra o arquivo de credenciais (client_secret.json) para baixar"
    echo "  e o passo a passo completo de onde salvá-lo e como rodar 'gws auth login'."
  fi
else
  say "Pulando Google Workspace."
fi

# ----------------------------------------------------------------------------
# Concluído
# ----------------------------------------------------------------------------
say "Configuração concluída!"
echo "  Modelo padrão: $(hermes config get model.default 2>/dev/null || echo 'anthropic/claude-sonnet-5')"
echo "  MCPs configurados: hermes mcp list"
echo "  Terminal: hermes chat"
echo "  Desktop:  hermes desktop"
say "Dúvidas? Canal #construindo-com-ia"
