# Privacy Policy (DRAFT - needs owner and lawyer sign-off)

Engineering draft. Not legal advice. Do not publish without review.

## English

What stays on device only: calendar events, tasks, notes, countdowns, tags. They leave only via Google sync, directly app to Google. Server never receives them.

What server stores (email account only): email + password hash + habits, habit logs, focus sessions. Nothing else. Used only for sync.

Tokens: sign-in tokens in device secure storage (keystore); never in OS backups without exclusion rules (see SECURITY_REVIEW.md).

No tracking: no analytics, advertising, or crash-reporting SDKs. No location, Bluetooth, or sensor data.

Rights (LGPD): export data (Settings > Backup); request deletion (Settings > Account > Delete remote data removes habits/focus from server). Add DPO contact before release.

Retention: local data until deleted. Server habit/focus data deleted on account deletion.

## Portugues (resumo)

O que fica so no dispositivo: eventos, tarefas, notas, contagens, etiquetas. Saem apenas na sincronizacao com Google, direto do app para servidores do Google. Nosso servidor nunca os recebe.

O que o servidor guarda (so com conta de e-mail): e-mail, hash da senha, habitos, registros de habitos, sessoes de foco. Nada mais.

Sem rastreamento: sem analytics, anuncios ou coleta de localizacao.

Direitos (LGPD): exporte dados (Ajustes > Backup) e peca exclusao (Conta > Excluir dados remotos). Adicionar contato do controlador/DPO antes do lancamento.