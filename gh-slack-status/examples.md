# Exemplos — gh-slack-status

## Entrada (JSON resumido)

Repo: `fscampini/operscale`, `--since 2026-06-27`

```json
{
  "since_label": "sexta-feira",
  "completed": [
    { "number": 17, "title": "Conciliação: execução assíncrona e UX resiliente a timeout HTTP", "is_pull_request": false },
    { "number": 20, "title": "Fix/reconciliation run timeout ux", "is_pull_request": true },
    { "number": 14, "title": "Corrigir preview de importação de obrigações em produção", "is_pull_request": false },
    { "number": 21, "title": "Fix/import preview cors upload limits", "is_pull_request": true },
    { "number": 22, "title": "Feat/mvp iam hardening step9", "is_pull_request": true },
    { "number": 23, "title": "Add marketing site directory with landing page source.", "is_pull_request": true },
    { "number": 24, "title": "Align IAM policy repo with AWS by removing self key rotation.", "is_pull_request": true },
    { "number": 8, "title": "Implementação MVP EC2 AWS (Terraform, app e release)", "is_pull_request": false }
  ],
  "open": [
    { "number": 18, "title": "Deploy marketing site to www.operscale.ai via Cloudflare Pages", "blockers": ["GitHub org da empresa + repo transferido — bloqueador Step 3"] },
    { "number": 19, "title": "Conciliação Fase 16: monitor global_admin + agendamento Celery Beat" },
    { "number": 11, "title": "Limpar backend/infra para escopo MVP EC2" }
  ]
}
```

## Saída esperada (Slack mrkdwn)

```
*O que foi feito (desde sexta-feira)*

• *Conciliação bancária*
    ◦ A conciliação passou a rodar em segundo plano, sem travar a tela quando a requisição demora (<https://github.com/fscampini/operscale/issues/17|#17>)
    ◦ O código dessa melhoria foi integrado na `main` (<https://github.com/fscampini/operscale/issues/20|#20>)

• *Importação de obrigações*
    ◦ O preview de importação de obrigações voltou a funcionar em produção, corrigindo o timeout de 60 segundos (<https://github.com/fscampini/operscale/issues/14|#14>)
    ◦ Também foram corrigidos problemas de CORS e limite de upload nesse fluxo (<https://github.com/fscampini/operscale/issues/21|#21>)

• *Segurança e infraestrutura AWS*
    ◦ O hardening de IAM do MVP foi feito: permissões mais restritas, sem `AdministratorAccess` (<https://github.com/fscampini/operscale/issues/22|#22>)
    ◦ A policy IAM no repositório foi alinhada com o que está na AWS (<https://github.com/fscampini/operscale/issues/24|#24>)
    ◦ A implementação completa do MVP na EC2 (Terraform, app, release e passos finais de IAM) foi encerrada (<https://github.com/fscampini/operscale/issues/8|#8>)

• *Site de marketing*
    ◦ O diretório do site institucional com a landing page foi adicionado ao repositório (<https://github.com/fscampini/operscale/issues/23|#23>)

*Próximos passos*

• *Colocar o site de marketing no ar* (<https://github.com/fscampini/operscale/issues/18|#18>)
    ◦ O código da landing page e o DNS na Cloudflare já estão prontos; o próximo passo é criar a org no GitHub e transferir o repositório de `fscampini/operscale` para ela (bloqueador atual).
    ◦ Depois disso: conectar o Cloudflare Pages ao repo, publicar o site em `www.operscale.ai` com HTTPS e validar redirects e email.

• *Painel de conciliação para admins + execução automática* (<https://github.com/fscampini/operscale/issues/19|#19>)
    ◦ Criar tela para `global_admin` ver execuções de conciliação de todos os clientes.
    ◦ Configurar Celery Beat para rodar a conciliação automaticamente (pass noturno).

• *Limpar a pasta de infraestrutura* (<https://github.com/fscampini/operscale/issues/11|#11>)
    ◦ Remover artefatos Terraform de ambientes não usados no MVP (dev/staging/production) e esqueletos de ECS.
    ◦ Confirmar que esses ambientes nunca foram aplicados na AWS antes de apagar.
```

## Notas sobre consolidação

- **#20** não aparece sozinho — complementa #17 na mesma categoria.
- **#21** aparece como detalhe de #14, não como linha isolada de "merge de PR".
- **#8** fecha o épico MVP; #22 e #24 são entregas distintas dentro de segurança.
- O usuário pode pedir para **omitir** issues abertas (ex.: não listar #19) ou **adicionar** itens manuais (ex.: "Explorar mais o produto para ganhar familiaridade com ele.").

## Invocação

```
/gh-slack-status --since friday fscampini/operscale
/gh-slack-status --since 2026-06-27
/gh-slack-status
```
