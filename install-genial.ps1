# ============================================================================
# Facilitador de Configuração do Hermes — Genial Care
# Windows (PowerShell)
#
# Uso:
#   iex (irm https://raw.githubusercontent.com/GenialCare/hermes-profile-genial/main/install-genial.ps1)
#
# O que faz (NAO cria profile - configura o Hermes PADRAO da sua maquina):
#   1. Verifica se o Hermes esta instalado (se nao, orienta a instalar e para)
#   2. Configura o provider LLM (Claude Sonnet 5 via OpenRouter)
#   3. Pergunta, um a um, quais MCPs corporativos voce usa e autentica so esses
#   4. Conecta o browser via CDP (Chrome com perfil isolado, login persiste)
#   5. Ativa a busca DuckDuckGo
#   6. Pergunta se voce usa Google Workspace e instala o gws CLI (a autenticacao
#      e feita separadamente, seguindo a Parte 4 da documentacao no Confluence).
#      Se o Node.js do Hermes nao estiver no PATH (comum quando instalado sem
#      winget), o script encontra e adiciona automaticamente.
#
# Idempotente: pode rodar de novo sem duplicar nada.
# ============================================================================
$ErrorActionPreference = "Stop"

$HermesHomeDir = if ($env:HERMES_HOME) { $env:HERMES_HOME } else { Join-Path $HOME ".hermes" }

function Say($msg)  { Write-Host "`n==> $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "`n==> $msg" -ForegroundColor Yellow }
function Err($msg)  { Write-Host "`n==> $msg" -ForegroundColor Red }

function Ask-Yes($question) {
    $resp = Read-Host "$question [s/N]"
    return $resp -match '^(s|sim|y|yes)$'
}

# O instalador do Hermes no Windows as vezes instala o Node.js portatil em
# %LOCALAPPDATA%\hermes\node (quando o winget nao esta disponivel) mas NAO
# adiciona esse diretorio ao PATH. Isso faz com que "npm" nao seja encontrado
# mesmo com o Node instalado. Esta funcao procura o npm nesse local conhecido
# e, se encontrar, adiciona ao PATH da sessao atual E ao User PATH persistente
# (para nao precisar repetir isso a cada novo terminal).
function Find-NpmPath {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        return (Get-Command npm).Source
    }

    $Candidates = @(
        (Join-Path $env:LOCALAPPDATA "hermes\node"),
        (Join-Path $HermesHomeDir "node")
    ) | Select-Object -Unique

    foreach ($NodeDir in $Candidates) {
        $NpmCmd = Join-Path $NodeDir "npm.cmd"
        if (Test-Path $NpmCmd) {
            Say "Encontrei o Node.js do Hermes em $NodeDir (nao estava no PATH)."
            # PATH da sessao atual (para o resto deste script)
            $env:Path = "$NodeDir;$env:Path"
            # PATH persistente do usuario (para novos terminais nao precisarem disso de novo)
            $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
            if ($UserPath -notlike "*$NodeDir*") {
                [Environment]::SetEnvironmentVariable("Path", "$NodeDir;$UserPath", "User")
                Say "Adicionado $NodeDir ao PATH do usuario (novos terminais ja vao encontrar o npm)."
            }
            return $NpmCmd
        }
    }
    return $null
}

# ----------------------------------------------------------------------------
# 1. Hermes instalado?
# ----------------------------------------------------------------------------
if (-not (Get-Command hermes -ErrorAction SilentlyContinue)) {
    Err "Hermes nao esta instalado."
    Say "Instale primeiro e depois rode este script de novo:"
    Write-Host "  iex (irm https://hermes-agent.nousresearch.com/install.ps1)"
    exit 1
}

Say "Hermes encontrado: $((Get-Command hermes).Source)"

# ----------------------------------------------------------------------------
# 2. Provider LLM padrao (Claude Sonnet 5 via OpenRouter)
# ----------------------------------------------------------------------------
Say "Configurando provider LLM (Claude Sonnet 5 via OpenRouter)..."
hermes config set model.default anthropic/claude-sonnet-5
hermes config set model.provider openrouter
hermes config set model.base_url https://openrouter.ai/api/v1
hermes config set model.api_mode chat_completions
hermes config set auxiliary.skills_hub.provider openrouter
hermes config set auxiliary.skills_hub.model anthropic/claude-sonnet-5
hermes config set delegation.model anthropic/claude-sonnet-5
hermes config set delegation.provider openrouter

# Chave OpenRouter
$EnvFile = Join-Path $HermesHomeDir ".env"
$HasKey = $false
if (Test-Path $EnvFile) {
    $HasKey = Select-String -Path $EnvFile -Pattern '^OPENROUTER_API_KEY=.' -Quiet -ErrorAction SilentlyContinue
}
if (-not $HasKey) {
    $Key = Read-Host "Cole sua chave OpenRouter (sk-or-...) e pressione Enter"
    if ($Key) {
        Add-Content -Path $EnvFile -Value "OPENROUTER_API_KEY=$Key"
        Say "Chave salva em $EnvFile"
    } else {
        Err "Chave OpenRouter nao informada. Sem ela, o Hermes nao funciona."
        Say "Peca o convite (invite) do OpenRouter para o Matheus Caceres no canal #construindo-com-ia e rode este script de novo."
        exit 1
    }
} else {
    Say "Chave OpenRouter ja configurada."
}

# ----------------------------------------------------------------------------
# 3. MCPs corporativos - um a um, so se a pessoa usar
# ----------------------------------------------------------------------------
$McpAtlassianUrl = "https://mcp.atlassian.com/v1/mcp"
$McpGranolaUrl   = "https://mcp.granola.ai/mcp"
$McpSlackUrl     = "https://mcp.slack.com/mcp"
$McpMetabaseUrl  = "https://analytics-panel.genialcare.com.br/api/mcp"

function Setup-Mcp($Name, $Url) {
    if (Ask-Yes "Voce usa o MCP ${Name}?") {
        Say "Configurando MCP $Name..."
        hermes mcp add $Name --url $Url --auth oauth
        switch ($Name) {
            "slack" {
                # client_id contem um ponto entre digitos (ex.: 123.456) - "hermes config set"
                # faz parse numerico do valor e TRUNCA para float, corrompendo o client_id.
                # Editamos o YAML diretamente com o Python do venv do Hermes (sempre tem
                # PyYAML) para garantir que o valor seja gravado como string.
                $PyBin = Join-Path $HermesHomeDir "hermes-agent\venv\Scripts\python.exe"
                if (Test-Path $PyBin) {
                    $ConfigPath = Join-Path $HermesHomeDir "config.yaml"
                    $PyScript = @'
import sys, yaml
path = sys.argv[1]
with open(path) as f:
    data = yaml.safe_load(f) or {}
data.setdefault("mcp_servers", {}).setdefault("slack", {}).setdefault("oauth", {})["client_id"] = "1451718280373.11571103729251"
with open(path, "w") as f:
    yaml.safe_dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
'@
                    $TmpPy = [System.IO.Path]::GetTempFileName() + ".py"
                    Set-Content -Path $TmpPy -Value $PyScript -Encoding UTF8
                    & $PyBin $TmpPy $ConfigPath
                    Remove-Item $TmpPy -Force
                } else {
                    Warn "Nao encontrei o Python do Hermes em $PyBin. Configure manualmente em $HermesHomeDir\config.yaml:"
                    Write-Host "    mcp_servers.slack.oauth.client_id (como STRING, entre aspas) = '1451718280373.11571103729251'"
                }
                hermes config set mcp_servers.slack.oauth.redirect_port 8932
            }
            "metabase" {
                hermes config set mcp_servers.metabase.headers.User-Agent 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
            }
        }
        Say "Autenticando $Name (abre o browser)..."
        if ($env:SKIP_MCP_LOGIN) {
            Warn "SKIP_MCP_LOGIN=1: pulando o login de $Name (modo de teste)."
        } else {
            try {
                hermes mcp login $Name
            } catch {
                Warn "Falha no login de $Name. Repita depois: hermes mcp login $Name"
            }
        }
    } else {
        Say "Pulando $Name."
    }
}

Say "Vamos configurar os MCPs corporativos. Responda apenas os que voce usa."
Setup-Mcp "atlassian" $McpAtlassianUrl
Setup-Mcp "granola"   $McpGranolaUrl
Setup-Mcp "slack"     $McpSlackUrl
Setup-Mcp "metabase"  $McpMetabaseUrl

# ----------------------------------------------------------------------------
# 4. Browser connect (CDP)
# ----------------------------------------------------------------------------
Say "Configurando conexao com o browser (CDP)..."
hermes config set browser.cdp_url http://127.0.0.1:9222

$CdpUp = $false
if ($env:SKIP_BROWSER) {
    Warn "SKIP_BROWSER=1: pulando a abertura do Chrome (modo de teste)."
    $CdpUp = $true
} else {
try {
    Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:9222/json/version" -TimeoutSec 2 | Out-Null
    $CdpUp = $true
} catch { $CdpUp = $false }
}

if (-not $CdpUp) {
    Say "Abrindo Chrome com depuracao remota (perfil isolado em $HermesHomeDir\chrome-debug)..."
    $ChromeCandidates = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    )
    $Chrome = $ChromeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($Chrome) {
        $ChromeDebugDir = Join-Path $HermesHomeDir "chrome-debug"
        Start-Process $Chrome -ArgumentList `
            '--remote-debugging-port=9222', `
            "--user-data-dir=$ChromeDebugDir", `
            '--no-first-run', `
            '--no-default-browser-check'
        Start-Sleep -Seconds 3
    } else {
        Warn "Chrome nao encontrado automaticamente. Abra manualmente com:"
        Write-Host "  chrome.exe --remote-debugging-port=9222 --user-data-dir=$HermesHomeDir\chrome-debug"
        Write-Host "e depois rode /browser connect dentro do Hermes."
    }
} elseif (-not $env:SKIP_BROWSER) {
    Say "Chrome ja esta respondendo na porta 9222."
}
Say "Browser conectado via CDP em 127.0.0.1:9222. Faca login uma vez na janela do Chrome - ele persiste entre sessoes."

# ----------------------------------------------------------------------------
# 5. Busca DuckDuckGo
# ----------------------------------------------------------------------------
Say "Configurando busca DuckDuckGo..."
try { hermes tools post-setup ddgs } catch { Warn "Nao consegui instalar o ddgs automaticamente. Rode depois: hermes tools post-setup ddgs" }
hermes config set web.search_backend ddgs

# ----------------------------------------------------------------------------
# 6. Google Workspace (gws) - opcional, sem autenticar automaticamente
# ----------------------------------------------------------------------------
if (Ask-Yes "Voce usa Google Workspace (Drive, Gmail, Calendar, Sheets, Docs)?") {
    if (-not (Get-Command gws -ErrorAction SilentlyContinue)) {
        Say "Instalando o gws CLI..."
        $NpmPath = Find-NpmPath
        if ($NpmPath) {
            & $NpmPath install -g @googleworkspace/cli
        } else {
            Warn "npm nao encontrado (nem no PATH, nem no Node portatil do Hermes)."
            Write-Host "  Baixe o binario em https://github.com/googleworkspace/cli/releases e coloque no PATH."
        }
    } else {
        Say "gws ja esta instalado."
    }

    if (Get-Command gws -ErrorAction SilentlyContinue) {
        Say "gws instalado. Antes de continuar, autentique-o (isso abre o browser):"
        Write-Host "  1. Baixe o client_secret.json anexado na documentacao do Confluence (Parte 4)."
        Write-Host "  2. Salve em $env:USERPROFILE\.config\gws\client_secret.json"
        Write-Host "  3. Rode: gws auth login"
        Write-Host ""
        if (Ask-Yes "Voce ja rodou 'gws auth login' com sucesso e quer que o Hermes configure a skill agora?") {
            $GwsStatusJson = ""
            try { $GwsStatusJson = (gws auth status 2>$null) -join "`n" } catch { $GwsStatusJson = "" }
            $GwsAuthenticated = $GwsStatusJson -match '"auth_method":\s*"(?!none")[^"]+"'
            if ($GwsAuthenticated) {
                Say "Configurando a skill do Google Workspace no Hermes (isso pode levar alguns segundos)..."
                hermes -z "eu ja configurei o gws por fora, entao configure a skill para utilizar essas credenciais no hermes" --yolo --accept-hooks -s google-workspace
                Say "Pronto. Se algo nao tiver funcionado, abra o Hermes e envie de novo:"
                Write-Host "  /google-workspace eu ja configurei o gws por fora, entao configure a skill para utilizar essas credenciais no hermes"
            } else {
                Warn "O gws ainda nao esta autenticado (gws auth status retornou 'none'). Rode 'gws auth login' primeiro, depois no Hermes envie:"
                Write-Host "  /google-workspace eu ja configurei o gws por fora, entao configure a skill para utilizar essas credenciais no hermes"
            }
        } else {
            Say "Sem problema. Quando terminar o 'gws auth login', abra o Hermes e envie:"
            Write-Host "  /google-workspace eu ja configurei o gws por fora, entao configure a skill para utilizar essas credenciais no hermes"
        }
    }
} else {
    Say "Pulando Google Workspace."
}

# ----------------------------------------------------------------------------
# Concluido
# ----------------------------------------------------------------------------
Say "Configuracao concluida!"
$CurrentModel = try { hermes config get model.default } catch { "anthropic/claude-sonnet-5" }
Write-Host "  Modelo padrao: $CurrentModel"
Write-Host "  MCPs configurados: hermes mcp list"
Write-Host "  Terminal: hermes chat"
Write-Host "  Desktop:  hermes desktop"
Say "Duvidas? Canal #construindo-com-ia"
