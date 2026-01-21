# GitIssue-Manager — Visao Geral para Cliente (Portuguese)

## Title
GitIssue-Manager — Sincronizacao automatizada de issues e projetos para planejamento multi-repo

## Resumo (elevator pitch)
Converte documentos de planejamento em issues do GitHub e itens do ProjectV2, com pre-visualizacao (dry-run), rastreabilidade (logs de auditoria) e aplicacao segura por repositorio.

## Beneficios principais
- Onboarding de sprint mais rapido e consistente entre repositorios.
- Menos erros manuais ao criar/atualizar muitos tickets.
- Auditoria e governanca: todas as alteracoes sao registradas.
- Implantacao segura: primeiro dry-run, depois execucao por repositório para reduzir riscos.

## Como funciona (3 passos)
1. Parse: le `SPRINT.md` e arquivos de artefatos.
2. Preview: simula criacao de issues e atualizacoes no ProjectV2 (dry-run JSON).
3. Apply: aplica alteracoes aprovadas e registra no log de auditoria.

## Arquitetura (uma linha)
Parser leve -> executor (GitHub API + ProjectV2) -> logs de auditoria.

## Proximos passos sugeridos
- Demo: execute um dry-run para um repositorio de exemplo e revise `logs/dryrun_summary_*.json`.
- Piloto: aplique por repositorio em um conjunto reduzido de itens.
- Rollout: adote a convencao `TYPE-NNN` e integre ao fluxo de planejamento da equipe.
