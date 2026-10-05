# Auditoria: Radar 9Router v1.1.0

Data: 05/10/2026.

## Base e candidato

Primeiro GitHub Release do projeto. Não havia tags, releases ou PRs publicados para esta linha. Base editorial: início do histórico, incluindo todas as capacidades presentes no candidato.

Candidato de código validado: `58839a3a85722ea7f57673a8d07b7a4885f35f4e`. A tag `v1.1.0` inclui esse código e o commit seguinte apenas com notas, arte e esta auditoria. O SHA final da tag é conferido no remoto após o push.

Remoto oficial criado para esta publicação: https://github.com/LucasOl1337/omarchy-9router-radar. Branch `main`, uma worktree. O diretório da fonte local anterior virou o repo, preservando os caminhos em uso. Nenhum PR ou histórico remoto a integrar.

## Matriz de evidências

| Resultado | Evidência | Situação e validação |
| --- | --- | --- |
| Radar único e ícone 9R | Panel.qml, Content.qml | Integrado; IPC da barra confirma 9R, unified-radar, 21 contas e três gateways |
| Prioridade por cota e renovação | RadarModel.js | Integrado; seis testes Node cobrem identidade, sessão esgotada, cota vencida, erro e offline |
| Uso por período e por origem | collect.py, Content.qml | Integrado; testes de contadores históricos e leitura preservada |
| Credenciais e SSH configuráveis | collect.py, routers.example.json | Integrado; testes de comando em lista, ausência de credencial e quoting SSH |
| Instalação completa e atualização sem cache | install.py | Integrado; dois testes de hash, unidades systemd instaladas, coleta terminou com Result=success |

## Validações e implantação

`python3 -m unittest discover -s tests -v`: oito testes passaram. `node --test tests/test_radar.cjs`: seis testes passaram. `python3 -m py_compile collect.py install.py`: passou. `omarchy-plugin-validate .`: passou. O instalador foi executado na máquina e a coleta do serviço instalado terminou com sucesso; timer ativo. O cadastro legado foi mantido para os três gateways existentes.

## Agentes e sessões

- Codex: esta conversa, sessão `01a10b89-ddb6-7973-a1f9-fef9dd71f84c`, implementou e publicou as duas entregas. Confiança alta, com código, comandos de teste e diagnóstico da barra nesta sessão.
- Codex: índices locais de 05/10 também apontaram referências nas sessões `01a10b9c-424f-7e91-843e-de132fe576b5` e `01a10bd8-99c2-7801-b6ed-0f8b6889fecd`. Referência ao caminho não comprova contribuição; nenhuma entrega foi atribuída a elas.
- Claude: índice de diretórios em `.claude/projects`, nenhuma sessão com caminho de projeto relacionado encontrada nessa fonte.
- Hermes: índice `.hermes/sessions/sessions.json`, nenhum caminho alvo encontrado.
- Grok: índice de diretórios em `.grok/sessions`, nenhum caminho alvo encontrado.
- Pi: índice de diretórios em `.pi/agent/sessions`, nenhum caminho alvo encontrado.
- Orca: fonte local indisponível, nenhum diretório de histórico identificado.

A consulta ficou nos índices e nas referências aos caminhos dos dois projetos. Ausência nesses índices não prova ausência de trabalho de outro agente. Transcrições brutas não entram no release.

## Publicação, exclusões e limites

Notas e arte incluídas no candidato, sob docs/releases. Código licenciado em MIT. Pacote de fontes gerado com git archive da tag e anexado ao GitHub Release com PNG e SVG. Sem credenciais, caches Python, estado local ou dados de runtime nos commits.

Migrations de banco remoto: não aplicável. Deploy em servidor/cloud: não aplicável, plugin desktop; a implantação aplicável é a instalação local verificada. CI remoto obrigatório: não existe neste projeto. Sem tarefas pendentes de integração no escopo.

As limitações de hardware/provedor constam nas notas e no README. A leitura de quotas segue a API do 9Router; a edição de mouse fica restrita ao modelo validado. A verificação remota confere tag, SHA, release publicado e assets depois de cada operação.
