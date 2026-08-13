# Hermes Genial — regras de contribuição

Este repositório contém scripts facilitadores para configurar o Hermes Agent padrão (não um profile) com o setup da Genial Care: provider LLM, MCPs corporativos, browser connect, busca e Google Workspace.

Ao trabalhar neste repositório, siga estas regras.

## Commits

- Todos os commits devem seguir **Conventional Commits**: `tipo(escopo): descrição`
- Tipos válidos: `feat, fix, docs, refactor, chore, test, perf, style, build, ci, revert`
- Descrição no imperativo e em português (ex.: `feat(mcp): adiciona pergunta de uso do metabase`)
- Proibidas mensagens vagas ("wip", "ajustes", "commit")

## Pull requests

- Título do PR também em **Conventional Commits**
- Antes de commitar, confira `git status` para garantir que nenhum segredo está staged
- Mudanças em `install-genial.sh` devem passar `bash -n install-genial.sh` antes do commit
- Mudanças em `install-genial.ps1` devem ser testadas em uma máquina Windows real antes do merge (não há como validar sintaxe PowerShell em macOS/Linux)
- Scripts devem continuar idempotentes: rodar duas vezes não deve duplicar entradas de config nem repetir perguntas já respondidas com "não"
