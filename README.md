# Hermes Profile Genial Care

Distribuição oficial do **Hermes Agent** para a Genial Care — um profile pronto com OpenRouter, MCPs corporativos e as skills bundled do Hermes.

## O que é

Este repositório é uma *profile distribution* do Hermes Agent. Quem instala recebe um agente completo e configurado: modelo via OpenRouter (roteamento automático), conexões MCP (Atlassian, Slack, Granola e Metabase) e o catálogo de skills padrão — sem precisar configurar nada manualmente.

- **Dados pessoais nunca saem da sua máquina:** memórias, sessões, chaves de API e configurações locais ficam só com você.
- **Sem git necessário para instalar:** o instalador baixa um arquivo pronto e faz tudo.

## Pré-requisitos

- **Hermes Desktop** (recomendado): baixe em [hermes-agent.nousresearch.com](https://hermes-agent.nousresearch.com/) — macOS (DMG) ou Windows (EXE). O instalador cria o CLI junto.
- Alternativa via terminal:
  - macOS/Linux: `curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash`
  - Windows (PowerShell): `iex (irm https://hermes-agent.nousresearch.com/install.ps1)`
- **Chave OpenRouter:** solicite no canal `#construindo-com-ia` no Slack.

## Instalação rápida

Escolha o comando do seu sistema, cole no Terminal/PowerShell e pressione Enter:

**macOS / Linux**

```bash
curl -fsSL https://github.com/matheusca/hermes-profile-genial/releases/latest/download/install-genial.sh | bash
```

**Windows (PowerShell)**

```powershell
iex (irm https://github.com/matheusca/hermes-profile-genial/releases/latest/download/install-genial.ps1)
```

O script faz tudo: instala o Hermes (se preciso), instala o profile `genial`, define como padrão, salva sua chave OpenRouter e autentica os MCPs um a um no browser.

## O que vem configurado

| Item | Configuração |
| --- | --- |
| Modelo padrão | `openrouter/auto` (roteamento automático do OpenRouter) |
| Tarefas auxiliares/delegação | `deepseek/deepseek-v4-pro` |
| MCPs | Atlassian, Slack, Granola, Metabase (OAuth por usuário) |
| Skills | Catálogo bundled do Hermes |
| Segurança | Redação automática de segredos ativa |

## Atualizações

Basta rodar o mesmo comando de instalação de novo — ou, se preferir:

```bash
hermes profile update genial
```

O que **é preservado** em atualizações: seu `config.yaml` (modelo/provider que você escolher), `.env`, memórias, sessões e qualquer arquivo em `local/`.

O que **é substituído** (padrão da empresa): `SOUL.md`, `skills/`, `cron/` e o restante da distribuição.

> Skills pessoais devem ser instaladas no seu profile **default** (não no `genial`) — assim nunca são perdidas em atualizações.

## Como contribuir

1. Crie uma branch a partir da `main`.
2. Faça suas mudanças (config, skills, scripts, docs).
3. Abra um PR com título em **Conventional Commits** (ex.: `feat(config): adiciona novo MCP`).
4. A CI valida automaticamente: mensagens de commit e título do PR devem seguir Conventional Commits (`feat, fix, docs, refactor, chore, test, perf, style, build, ci, revert`).
5. Ao mudar o conteúdo da distribuição, incremente a versão em `distribution.yaml`.
6. **Releases:** a cada tag `vX.Y.Z` criada, o GitHub Actions gera automaticamente os arquivos (`zip`/`tar.gz` com a versão e `-latest`) e os scripts de instalação.

```bash
# Exemplo de release
git tag v0.2.0 && git push origin v0.2.0
```

## FAQ

- **Não tenho chave OpenRouter:** envie uma mensagem no canal `#construindo-com-ia` pedindo acesso.
- **O login de um MCP falhou:** repita com `hermes -p genial mcp login <nome>` (atlassian, granola, slack ou metabase).
- **Quero outro modelo:** `hermes -p genial config set model.default <modelo>` (ex.: `z-ai/glm-5.2`).
- **Dúvidas:** canal `#construindo-com-ia` no Slack.
