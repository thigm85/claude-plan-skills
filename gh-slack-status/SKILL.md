---
name: gh-slack-status
description: Gera resumo Slack do que foi feito desde uma data e próximos passos a partir de issues GitHub. Use quando o usuário pedir "resumo slack", "status update", "o que foi feito desde...", ou quiser postar progresso no Slack.
argument-hint: "[--since friday|YYYY-MM-DD] [owner/repo]"
allowed-tools: Bash, Read
---

Gere um resumo pronto para colar no Slack a partir da atividade de issues no GitHub.

## Argumentos

Parse `$ARGUMENTS` (ou pergunte se vazio):

| Argumento | Default | Exemplo |
|-----------|---------|---------|
| `owner/repo` | repo atual (`gh repo view`) | `fscampini/operscale` |
| `--since DATE` | `friday` | `2026-06-27`, `3-days`, `monday`, `today` |

## Workflow

1. **Resolver repo e data** a partir dos argumentos ou do contexto da conversa.
2. **Executar o script** (caminho relativo a esta skill):

```bash
bash "$(dirname "$0")/scripts/fetch-issue-activity.sh" --repo OWNER/REPO --since DATE
```

Se o agente não tiver `$0`, use o caminho absoluto da skill ou:

```bash
bash ~/.claude/claude-plan-skills/gh-slack-status/scripts/fetch-issue-activity.sh --repo OWNER/REPO --since DATE
```

3. **Ler o JSON** retornado (`completed`, `open`, `since_label`).
4. **Sintetizar "O que foi feito"**:
   - Agrupar por tema (Conciliação, Importação, Infra AWS, Marketing, etc.)
   - Uma frase simples por entrega, em português brasileiro
   - Consolidar issues relacionadas (ex.: #17 + #20 → uma linha de conciliação)
   - Omitir issues `is_pull_request: true` quando a issue pai já cobre a entrega (#20 sob #17, #21 sob #14, #15/#20/#21 como detalhe de merge)
   - Incluir PRs quando forem a entrega principal (#22 IAM, #23 marketing, #24 policy)
5. **Sintetizar "Próximos passos"**:
   - Ordenar: bloqueadores → valor de negócio → higiene técnica
   - Usar `blockers` e `next_steps` do JSON
   - Máximo ~2 sub-bullets por issue aberta
   - Incorporar itens extras que o usuário pedir (ex.: "explorar o produto")
6. **Formatar para Slack** e entregar o texto final — pronto para colar, sem explicação extra.

## Template Slack (mrkdwn)

```
*O que foi feito (desde {since_label})*

• *{Categoria}*
    ◦ {frase simples} (<https://github.com/{repo}/issues/{N}|#{N}>)

*Próximos passos*

• *{Título da frente}* (<https://github.com/{repo}/issues/{N}|#{N}>)
    ◦ {contexto ou bloqueador}
    ◦ {próxima ação}

• {item manual sem issue, se solicitado}
```

## Regras de estilo

- Português brasileiro, tom direto, sem jargão desnecessário
- Links no formato Slack: `<https://github.com/OWNER/REPO/issues/N|#N>`
- Negrito no Slack: `*texto*` (não `**texto**`)
- Bullets: `•` para nível 1, `◦` para sub-itens (4 espaços de indentação)
- Não listar issues abertas sem trabalho pendente relevante
- Não duplicar entregas entre issue pai e PR filho

## Consolidação de issues

| Padrão | Ação |
|--------|------|
| Issue pai fechada + PRs mergeados (#14 + #21) | Uma ou duas frases sob o tema pai; PR só se agregar detalhe distinto |
| Issue de implementação + PR de merge (#17 + #20) | Uma frase sobre a entrega; citar #17 (ou #17 e #20 se ambos relevantes) |
| PR como entrega isolada (#22, #23, #24) | Incluir normalmente |
| Issue aberta com gate/bloqueador | Mencionar bloqueador no primeiro sub-bullet |

## Referência

Para tom e nível de consolidação, veja [examples.md](examples.md).
