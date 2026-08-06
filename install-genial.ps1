# ============================================================================
# Instalador do Profile "genial" — Hermes Agent da Genial Care
# Windows (PowerShell)
#
# Uso:
#   iex (irm https://github.com/matheusca/hermes-profile-genial/releases/latest/download/install-genial.ps1)
#
# O que faz:
#   1. Instala o Hermes Agent (se não estiver instalado; o instalador do
#      Windows provisiona o git embutido automaticamente)
#   2. Baixa e instala o profile "genial" (distribuição oficial da empresa)
#   3. Define o profile genial como padrão
#   4. Salva sua chave OPENROUTER_API_KEY no .env do profile (se ausente)
#   5. Guia o login OAuth de cada MCP corporativo (atlassian, granola, slack, metabase)
# ============================================================================
$ErrorActionPreference = "Stop"

$BaseUrl     = "https://github.com/matheusca/hermes-profile-genial/releases/latest/download"
$ProfileName = "genial"
$Archive     = "hermes-genial-latest.zip"
$McpList     = @("atlassian","granola","slack","metabase")

# ----------------------------------------------------------------------------
# 1. Hermes instalado?
# ----------------------------------------------------------------------------
if (-not (Get-Command hermes -ErrorAction SilentlyContinue)) {
    Write-Host "==> Hermes Agent não encontrado — instalando..." -ForegroundColor Green
    iex (irm https://hermes-agent.nousresearch.com/install.ps1)
    # Recarrega o PATH para a sessão atual enxergar o hermes
    $env:Path = [Environment]::GetEnvironmentVariable("Path","User") + ";" + [Environment]::GetEnvironmentVariable("Path","Machine")
}

# ----------------------------------------------------------------------------
# 2. Baixar e extrair a distribuição
# ----------------------------------------------------------------------------
$Tmp = Join-Path $env:TEMP ("hermes-genial-" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $Tmp | Out-Null

Write-Host "==> Baixando o profile Genial ($Archive)..." -ForegroundColor Green
curl.exe -L -o (Join-Path $Tmp $Archive) "$BaseUrl/$Archive"
Expand-Archive (Join-Path $Tmp $Archive) -DestinationPath $Tmp

# ----------------------------------------------------------------------------
# 3. Instalar o profile (idempotente; dados do usuário são preservados)
# ----------------------------------------------------------------------------
Write-Host "==> Instalando o profile '$ProfileName'..." -ForegroundColor Green
hermes profile install (Join-Path $Tmp "hermes-genial") --name $ProfileName --alias --force -y

# ----------------------------------------------------------------------------
# 4. Definir o profile genial como padrão
# ----------------------------------------------------------------------------
Write-Host "==> Definindo '$ProfileName' como profile padrão..." -ForegroundColor Green
hermes profile use $ProfileName

# ----------------------------------------------------------------------------
# 5. Chave OpenRouter (se ausente, pergunta e grava no .env do profile)
# ----------------------------------------------------------------------------
$EnvFile = Join-Path $HOME ".hermes\profiles\$ProfileName\.env"
$HasKey = Select-String -Path $EnvFile -Pattern '^OPENROUTER_API_KEY=.' -Quiet -ErrorAction SilentlyContinue
if (-not $HasKey) {
    $Key = Read-Host "Cole sua chave OpenRouter (sk-or-...) e pressione Enter"
    if ($Key) {
        Add-Content -Path $EnvFile -Value "OPENROUTER_API_KEY=$Key"
        Write-Host "==> Chave salva em $EnvFile" -ForegroundColor Green
    } else {
        Write-Host "==> Sem chave agora? Adicione depois em $EnvFile" -ForegroundColor Yellow
    }
}

# ----------------------------------------------------------------------------
# 6. Login nos MCPs — um por vez, fluxo OAuth no browser
#    (SKIP_MCP_LOGIN=$true pula esta etapa — útil para testes)
# ----------------------------------------------------------------------------
if (-not $env:SKIP_MCP_LOGIN) {
    Write-Host "==> Autenticando nos MCPs (faça um por vez no browser)..." -ForegroundColor Green
    foreach ($mcp in $McpList) {
        Write-Host "==> MCP: $mcp" -ForegroundColor Green
        hermes -p $ProfileName mcp login $mcp
    }
}

# ----------------------------------------------------------------------------
# Concluído
# ----------------------------------------------------------------------------
Write-Host ""
Write-Host "Pronto! Profile '$ProfileName' instalado e definido como padrão." -ForegroundColor Green
Write-Host "  1. Terminal:  genial chat"
Write-Host "  2. Desktop:   hermes desktop  (se preferir a interface gráfica)"
Write-Host "Dúvidas? Canal #construindo-com-ia"
