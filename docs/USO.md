# Manual do Usuario - Ephemeron

Docs tecnicas: docs/ARCHITECTURE.md, docs/PRIVACY.md, docs/SECURITY_REVIEW.md.

## 1. Introducao
App de produtividade offline-first: calendario, tarefas, habitos, contagens regressivas, foco, notas e listas em um app rapido. Tudo funciona sem conta. Sincronizacao (Google e conta de e-mail) opcional.
Plataformas: Android (max), Linux e Web (medio), Windows (baixo), iOS e macOS (suportados).

## 2. Navegacao e interface
Sete secoes: Calendario, Tarefas, Matriz, Habitos, Contagens, Foco, Notas. Barra inferior com 5 primeiras fixas + botao Mais (demais, Busca, Ajustes, Personalizar navegacao). Personalizar: reordenar por arrasto, ordem salva. Ultima secao aberta restaurada ao abrir. FAB cria item principal da secao. Busca global via Mais ou /search. Home-screen widgets: Ajustes > Home-screen widgets lista tipos e fixa um (Android). Widgets atualizam ao abrir app. Widget de semana mostra semana inteira (itens de dia todo, eventos e tarefas com hora); toque em coluna abre essa semana.

## 3. Primeiro uso (onboarding)
Primeira execucao: 3 paginas (Pular sempre disponivel):
1. "Seu tempo, offline primeiro" - tudo funciona sem conta.
2. "Alarmes que tocam" - ao criar primeiro lembrete pede permissao de notificacao e alarme exato; teste de alarme em Ajustes.
3. "Sincronizar e opcional" - conectar Google para sincronizar calendario/tarefas, ou criar conta de e-mail para habitos/foco. Dados do Google nunca tocam servidor. Pule para ficar local.
Permissoes pedidas no momento de uso.

## 4. Calendario
Visualizacoes (menu no AppBar): Mes (grade com pontos); 3/4/7 dias (linha do tempo com hora atual, snap 15 min); Dia; Agenda (lista cronologica); Ano (mapa de calor). Navegacao setas anterior/proximo, icone Hoje. Topo mostra apenas "Calendar" (toque sincroniza), mes/ano abaixo.
Origem: detalhes de evento mostram calendario e conta de e-mail de origem; tarefa mostra lista e conta. Toque na origem escolhe conta e depois calendario. Evento movido na hora; ao sincronizar, mesma conta usa endpoint de mover do Google, contas diferentes copiam para destino e apagam origem. Series recorrentes so podem mudar de conta por copia local quando destino e local; entre contas Google mantenha serie na mesma conta.

Criar/editar evento (FAB ou toque em horario vazio): titulo, calendario, dia inteiro; datas/horas inicio e fim; repeticao (nao repete, diario, semanal, mensal, anual, ultimo dia do mes, RRULE customizado com validacao/exemplos); local, notas, participantes (virgula), link Meet (criar Meet), cor (colorId); fuso horario opcional (tzId).
Eventos recorrentes: ao editar escolha escopo - este, este e seguintes, ou todos. Alteracoes de horario em "todos": pergunta manter ou resetar alteracoes por ocorrencia.
Arrastar para mover com snap 15 min; em recorrentes pergunta escopo.

Calendarios (icone ajustes): listar, ativar/desativar, adicionar local. Config: inicio da semana (segunda/domingo/sabado), duracao padrao de evento.
Notas vinculadas: adicionar a partir dos detalhes do evento; lista nos detalhes; notas longas (>8000 chars) viram nota de overflow.

## 5. Tarefas
Tela principal: filtro por lista (chips horizontais), incluindo All e + List. Secao "Overdue (N)" com "Reschedule to today". Swipe concluir/excluir (desfazer, 6 s). AppBar: Concluidas (done_all) e Lixeira.
Criar/editar (editor ou adicao rapida): titulo, lista, prioridade 0-4, data de vencimento, fixar, notas, tags, subtarefas (parentId).
Adicao rapida (FAB): campo unico com atalho: #tag para etiquetas; ~lista para lista (cria se nao existir); -p1 a -p4 para prioridade (-p1 mais urgente); resto passa por parser de data/hora natural (EN e PT), incluindo recorrencia. Exemplo: Buy milk #groceries ~home -p1 tomorrow 9h. Chips de pre-visualizacao ao vivo; Salvar e Salvar e adicionar outro.

Matriz: tabuleiro 2x2 com quatro campos e bandeja separada para tarefas sem classificacao. Dois modos: Auto (padrao) quadrantes "Do first", "Schedule", "Delegate", "Eliminate" a partir de prioridade e vencimento; Priority cada campo mostra apenas tarefas da prioridade correspondente P1-P4. Modo salvo. FAB cria tarefa; toque edita. Origem (lista e conta) aparece e pode ser trocada no toque: escolha conta e depois lista. Tarefa movida na hora; sincronizacao usa mover na mesma conta ou copiar/apagar entre contas.
Lixeira: restaurar ou excluir definitivamente; concluidas em tela separada com reabrir.

## 6. Habitos
Frequencias: diario, dias da semana (mascara), semanal (meta de dias), a cada N dias. Secoes (criar pela edicao), arquivar/restaurar (icone AppBar). Navegador de 7 dias (faixa) para marcar conclusao. Registro em um toque; opcao de pular (skip) neutro para streaks. Meta quantitativa: quantidade + unidade. Data de inicio, lembrete (hora). Streak atual e melhor (saltos neutros nao estendem).

## 7. Contagens regressivas
Titulo, data alvo, repeticao anual, mostrar idade, notas. Grupos "Proximas" e "Passadas" ordenados por dias restantes, mais nao datadas. Editar/excluir com desfazer.

## 8. Foco
Presets de foco: 15, 25, 50 min; pausas: 5, 10, 15. Modo Stopwatch sem limite: conta para cima ate finalizar, sem alarme de fim. Timer baseado em timestamp (startedAt/targetEndUtc): sobrevive fechamento do app; tick por segundo apenas com tela visivel. Alarme nativo de fim de sessao (AlarmScheduler); nao se aplica ao Stopwatch. Historico e estatisticas: minutos de hoje e da semana. Sessoes podem ser associadas a habitos/tags.

## 9. Notas
Pastas aninhadas com breadcrumbs; mover entre pastas (anti-ciclo); excluir pasta reparenta filhos. Notas: criar, editar, fixar, duplicar, excluir (desfazer), lixeira. Editor Markdown: barra de ferramentas, alternancia editar/preview, checklists tocaveis, contagem palavras/caracteres, autosave 800 ms. Preview leve (GFM), lista lazy, cache por versao. Busca FTS5 com snippets destacados. Anexos em armazenamento content-addressed com limpeza de orfaos. Notas vinculadas a eventos (adicionar nos detalhes do evento).

## 10. Alarmes
Agendamento vinculado a lembretes/tarefas/foco, janela rolante (48 h + 60 futuros). Intensidades: leve (exact while idle), medio/forte/constante (setAlarmClock). Tela de toque (/ring): sem voltar para dispensar, soneca 10 min e Concluido; auto-soneca 30 s. Repeticao constante: a cada 1 min, max 30. Recuperacao apos reboot, mudanca de hora, fuso, atualizacao de app (receivers + leitura direta do indice de alarmes). Permissoes: alarme exato (conceder nas config do sistema), otimizacao de bateria (deep links). Teste de alarme (toca em 10 s). Alarmes perdidos listados em Ajustes. Orientacao para fabricantes (Xiaomi, Samsung, Huawei, Oppo) que bloqueiam alarmes. Plataformas: Android completo; iOS/desktop exibem notificacoes enquanto app aberto; Web exibe banner de indisponibilidade.

## 11. Busca global
Um campo de busca em tarefas, eventos, notas, habitos, contagens e tags. Filtros por tipo (chips): Tudo, Tarefas, Eventos, Notas, Habitos, Contagens, Tags. Resultados agrupados com contagem; linhas so exibicao (navegacao profunda em versao futura).

## 12. Sincronizacao
Google (Calendario e Tarefas): login (consent-first), funciona sem conta; escopos incrementais (Calendar e depois Tasks). Sync bidirecional com outbox, backoff com jitter, tratamento 410/401/403/429 com Retry-After. Mapeamento preserva campos locais (alarmPreset, colorId, dueTime, prioridade, rrule). Chip de status: Sincronizado/Sincronizando/Offline/Erro. Gatilhos: tocar no titulo de Calendario, Tarefas ou Matriz sincroniza agora e reinicia contagem; intervalo automatico configuravel (Desligado, 15 min, 30 min, 1 h, 2 h). Lista de alteracoes que falharam com Repetir/Descartar. Dados do Google vao direto do app para Google; nunca tocam servidor. Mudancas de conta/calendario/lista otimistas. Mesma conta push usa mover; entre contas cria no destino e apaga origem quando ambas conectadas.

Conta de e-mail (backend, opcional): criar conta ou entrar (e-mail + senha 8+). Sincroniza apenas habitos e sessoes de foco entre dispositivos. Calendario, tarefas, notas permanecem no dispositivo. Sincronizar agora, sair, Excluir dados remotos (remove habitos/foco do servidor; dados locais permanecem).

## 13. Ajustes
Grupos: Aparência (brilho claro/escuro/AMOLED, cor primaria 10 presets + hex, cor de fundo 6 presets + hex, idioma sistema/ingles/portugues; opcao ativa com marca de selecao); Comportamento e acessibilidade (modo economia auto/sempre ligado/sempre desligado, reduzir animacoes, haptics); Conta e sincronizacao (conta Google/backend, intervalo Google 0/15/30/60/120 min, intervalo habitos/foco); Seguranca (bloqueio biometrico); Dados e widgets (backup e home-screen widgets); Navegacao (reordenar secoes).

Backup: Exportar gera ephemeron-backup-<timestamp>.json com 21 tabelas, validado e transacional. Anexos (bytes) nao incluidos. Restaurar: selecionar arquivo da lista e confirmar. Indisponivel na Web ("File backups are not available on web yet.").

## 14. Plataformas e limitacoes conhecidas
Web: alarmes indisponiveis; backups de arquivo indisponiveis; Drift via WASM/IndexedDB (dados persistem). Desktop (Linux/macOS/Windows): notificacoes apenas enquanto app aberto; configurar caminhos de som por SO. Android: funcionalidade completa incluindo alarmes e recuperacao apos reboot. Sem SDK/dispositivo: matriz de alarmes em dispositivos fisicos, benchmark de bateria 24 h, auditoria de tamanho nao verificados (docs/TODO.md).

## 15. Privacidade e seguranca (resumo)
Eventos, tarefas, notas, contagens e etiquetas nunca saem do dispositivo, exceto na sincronizacao com Google (direto do app para servidores do Google). Servidor armazena apenas e-mail, hash da senha, habitos, registros de habitos e sessoes de foco (com conta de e-mail). Tokens em armazenamento seguro (keystore); nunca em SharedPreferences, logs ou backups. Sem analytics, anuncios ou coleta de localizacao. Sem rastreamento. Exportar dados via Ajustes > Backup; excluir dados remotos via Conta > Excluir dados remotos. Detalhes: docs/PRIVACY.md, docs/SECURITY_REVIEW.md.

## 16. Mapa da documentacao
- docs/ARCHITECTURE.md: arquitetura e especificacao.
- docs/PRIVACY.md: politica de privacidade (rascunho).
- docs/SECURITY_REVIEW.md: revisao de seguranca.
- docs/PROGRESS.md: status das fases.
- docs/TODO.md: pendencias e limites de ambiente.
- docs/decisions.md: decisoes de implementacao.
- server/README.md: setup do backend.