#!/usr/bin/env bash
# ============================================================================
# Instalador do Profile "genial" — Hermes Agent da Genial Care
# macOS / Linux
#
# Uso:
#   curl -fsSL https://github.com/matheusca/hermes-profile-genial/releases/latest/download/install-genial.sh | bash
#
# O que faz:
#   1. Instala o Hermes Agent (se não estiver instalado)
#   2. Baixa e instala o profile "genial" (distribuição oficial da empresa)
#   3. Define o profile genial como padrão
#   4. Salva sua chave OPENROUTER_API_KEY no .env do profile (se ausente)
#   5. Guia o login OAuth de cada MCP corporativo (atlassian, granola, slack, metabase)
# ============================================================================
set -euo pipefail

BASE_URL="${GENIAL_BASE_URL:-https://github.com/matheusca/hermes-profile-genial/releases/latest/download}"
PROFILE_NAME="${GENIAL_PROFILE_NAME:-genial}"
ARCHIVE="hermes-genial-latest.tar.gz"
MCP_LIST="atlassian granola slack metabase"

say()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m==>\033[0m %s\n' "$*"; }

# ----------------------------------------------------------------------------
# 1. Hermes instalado?
# ----------------------------------------------------------------------------
if ! command -v hermes >/dev/null 2>&1; then
  say "Hermes Agent não encontrado — instalando..."
  if ! command -v git >/dev/null 2>&1; then
    if [[ "$(uname)" == "Darwin" ]]; then
      say "Git ausente. Instalando Command Line Tools (pode pedir sua senha)..."
      xcode-select --install || true
      warn "Rode este script NOVAMENTE depois que a instalação do CLT terminar."
      exit 1
    else
      warn "Git ausente. Instale o git (ex.: sudo apt install git) e rode novamente."
      exit 1
    fi
  fi
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
  export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
fi

# ----------------------------------------------------------------------------
# 2. Baixar e extrair a distribuição (quem instala NÃO precisa de git)
# ----------------------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "Baixando o profile Genial ($ARCHIVE)..."
curl -fsSL "$BASE_URL/$ARCHIVE" -o "$TMP/$ARCHIVE"
tar -xzf "$TMP/$ARCHIVE" -C "$TMP"

# ----------------------------------------------------------------------------
# 3. Instalar o profile (idempotente; dados do usuário são preservados)
# ----------------------------------------------------------------------------
say "Instalando o profile '$PROFILE_NAME'..."
hermes profile install "$TMP/hermes-genial" --name "$PROFILE_NAME" --alias --force -y

# ----------------------------------------------------------------------------
# 4. Definir o profile genial como padrão
# ----------------------------------------------------------------------------
say "Definindo '$PROFILE_NAME' como profile padrão..."
hermes profile use "$PROFILE_NAME"

# ----------------------------------------------------------------------------
# 5. Chave OpenRouter (se ausente, pergunta e grava no .env do profile)
# ----------------------------------------------------------------------------
ENV_FILE="$HOME/.hermes/profiles/$PROFILE_NAME/.env"
if ! grep -q '^OPENROUTER_API_KEY=.' "$ENV_FILE" 2>/dev/null; then
  read -rsp "Cole sua chave OpenRouter (sk-or-...) e pressione Enter: " KEY
  echo
  if [[ -n "${KEY:-}" ]]; then
    echo "OPENROUTER_API_KEY=$KEY" >> "$ENV_FILE"
    say "Chave salva em $ENV_FILE"
  else
    warn "Sem chave agora? Adicione depois em $ENV_FILE (ou exporte OPENROUTER_API_KEY)."
  fi
fi

# ----------------------------------------------------------------------------
# 6. Login nos MCPs — um por vez, fluxo OAuth no browser
#    (SKIP_MCP_LOGIN=1 pula esta etapa — útil para testes)
# ----------------------------------------------------------------------------
if [[ -z "${SKIP_MCP_LOGIN:-}" ]]; then
  say "Autenticando nos MCPs (faça um por vez no browser):"
  for mcp in $MCP_LIST; do
    say "MCP: $mcp"
    hermes -p "$PROFILE_NAME" mcp login "$mcp" \
      || warn "Falha no login de $mcp. Repita depois: hermes -p $PROFILE_NAME mcp login $mcp"
  done
fi

# ----------------------------------------------------------------------------
# Concluído
# ----------------------------------------------------------------------------
say "Pronto! Profile '$PROFILE_NAME' instalado e definido como padrão."
say "  1. Terminal:  genial chat"
say "  2. Desktop:   hermes desktop  (se preferir a interface gráfica)"
say "Dúvidas? Canal #construindo-com-ia"
