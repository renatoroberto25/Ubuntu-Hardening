# Triagem do host-audits

Fonte: `host-audits-05_27_2026_-09_54_48-gmt-3.csv`.

Itens tratados como fora de escopo para VDI dev corporativo:

| Item | Resultado no host-audits | Acao na revisao |
| --- | --- | --- |
| 605, Firewall local ativo | FAILED | Removido do audit revisado |
| 606, UFW egress default DENY | N/A no CSV, existia no audit | Removido do audit revisado |
| 607, Audit conexoes outbound para IPs privados | FAILED | Removido do audit revisado |
| 608, Audit conexoes ports >1024 nao-whitelisted | N/A no CSV, existia no audit | Removido do audit revisado |
| 701, Cron desabilitado para usuarios comuns | FAILED | Removido do audit revisado |
| 901, File integrity baseline credenciais | FAILED | Removido do audit revisado |
| 1006, AIDE configurado | FAILED | Removido do audit revisado |
| 1008, UFW instalado e ativo | FAILED | Removido do audit revisado |
| 907, Audit syscalls criticos | FAILED | Mantido, mas sem cobrar socket/connect |

Decisao: o audit revisado deve medir o mesmo escopo do baseline realista. Controles de rede ficam em Citrix/firewall/proxy corporativo; AIDE fica fora sem processo de operacao; cron nao entra como controle obrigatorio para esse perfil.
