# Hermes Genial — regras de contribuição

Ao trabalhar neste repositório, siga estas regras.

## Commits

- Todos os commits devem seguir **Conventional Commits**: `tipo(escopo): descrição`
- Tipos válidos: `feat, fix, docs, refactor, chore, test, perf, style, build, ci, revert`
- Descrição no imperativo e em português (ex.: `feat(config): adiciona MCP do metabase`)
- Proibidas mensagens vagas ("wip", "ajustes", "commit")

## Pull requests

- Título do PR também em **Conventional Commits**
- Antes de commitar, confira `git status` para garantir que nenhum segredo (`.env`, `auth.json`) está staged
- Ao mudar o conteúdo da distribuição, incremente a versão em `distribution.yaml`
