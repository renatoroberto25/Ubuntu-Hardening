# Revisao VDI Dev Ubuntu 24.04

Escopo: hardening pratico para VDI de desenvolvimento em ambiente corporativo, com Citrix, firewall/proxy corporativo e controles de rede fora do host.

Arquivos criados nesta revisao:

- `Baseline-Proposta-Realista-VDI-DEV-REVISAO.txt`: copia do baseline realista usado como fonte.
- `baseline_ubuntu24_vdi_REVISAO.csv`: copia CSV do mesmo baseline.
- `Hardening-Ubuntu-2404-VDI-Desktop-v3-REVISAO.sh`: script baseado no v3, sem cobrar egress/firewall local como item manual.
- `COMPLIANCE_AUDIT_UBUNTU2404_VDI_DEV_REALISTA_REVISAO.audit`: audit revisado para medir o que o baseline realmente pede.
- `baseline_ubuntu24_vdi_FULL_AUDIT_REVISAO.csv`: baseline completo com campos de auditoria.
- `generate_audit_from_baseline_csv.py`: gerador CSV -> `.audit`.
- `COMPLIANCE_AUDIT_UBUNTU2404_VDI_DEV_REALISTA_FROM_CSV.audit`: audit gerado a partir do CSV completo.

Itens removidos do audit revisado:

- AIDE obrigatorio: itens `901` e `1006`.
- UFW/firewall/egress local: itens `605`, `606`, `607`, `608` e `1008`.
- Cron restrito a root: item `701`.
- Socket/connect no check generico de syscall: item `907` agora valida apenas `setuid/setgid`.

Motivo: esses controles geram ruido e falso negativo no perfil VDI dev. AIDE exige operacao para tratar alerta; firewall/egress fica na arquitetura corporativa; cron local nao e controle relevante para esse modelo.

Fluxo correto daqui para frente:

1. Editar `baseline_ubuntu24_vdi_FULL_AUDIT_REVISAO.csv`.
2. Regenerar o audit:

```sh
REVISAO/generate_audit_from_baseline_csv.py \
  REVISAO/baseline_ubuntu24_vdi_FULL_AUDIT_REVISAO.csv \
  REVISAO/COMPLIANCE_AUDIT_UBUNTU2404_VDI_DEV_REALISTA_FROM_CSV.audit
```

3. Usar o `.audit` gerado como artefato de compliance.
