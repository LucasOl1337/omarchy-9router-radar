# Auditoria: Radar 9Router v1.2.0

Data: 16/10/2026.

## Base e candidato

Base: tag `v1.1.0` (`b1f59b9`), último release publicado. Candidato: commit desta versão na `main`, sem branches, PRs ou worktrees a integrar; `main` estava igual a `origin/main` antes da mudança.

## Matriz de evidências

| Resultado | Evidência | Validação |
| --- | --- | --- |
| Cards no visual do Quota Tracker do 9Router | Content.qml, icons/ (ícones MIT do 9Router v0.5.95) | Renderizado numa bancada com dados reais e fictícios |
| Cores e contador `usado / total` | RadarModel.js `quotaView`, collect.py `clean_quotas` | Testes Node de limiares (70/30) e Python de `used/total` |
| Filtro por router, ordens e preferências | RadarModel.js `buildCards`, Content.qml, Panel.qml | Testes Node de filtro, contas removidas e ordenação; clique na bancada e `view.json` relido ao reabrir |
| Grade larga com linhas alinhadas | Content.qml `rowMax`, Panel.qml | Diagnóstico IPC na barra: 4 colunas, 22 cards, 3 gateways |
| Cota das contas desativadas | collect.py, script SSH | Coleta real trouxe as barras das duas contas desativadas do Sherlocker |
| Ícones na geração da interface | install.py | Teste de deploy com `icons/` |
| Cofre lento vira erro legível | collect.py | Teste de timeout do comando de senha |

## Validações

`python3 -m unittest discover -s tests`: 11 testes passaram. `node --test tests/test_radar.cjs`: 9 testes passaram. `omarchy-plugin-validate .`: passou. `python3 install.py` publicou a geração `2a3a83d19b59f7c5fdab`; o IPC da barra devolveu `version 1.2.0`, `layout quota-cards`.

## Agentes e sessões

- Claude Code (Opus 5.5), sessão `ff6f0170-ebc9-4ec7-ad65-53e7c3da2488`: implementação, testes, instalação e publicação desta versão.

## Pendências

Na coleta de validação, o Railway não atualizou porque outra sessão segurava a trava do `cofre` (migração do chaveiro). A barra manteve a última leitura e marcou o router; a próxima coleta normaliza quando o cofre liberar.

A arte usa dados fictícios porque o repositório é público.
