# Radar 9Router v1.2.0

16 de outubro de 2026

As cotas no mesmo visual do Quota Tracker do 9Router, todas lado a lado.

## Novidades

- **Cards iguais aos do painel.** Cada conta tem o ícone do provedor e uma barra por cota, verde, amarela ou vermelha conforme o que resta, com `usado / total`, porcentagem livre e tempo até renovar.
- **Tudo ao mesmo tempo.** O painel abre largo, em grade de três ou quatro colunas, e as barras da mesma linha ficam alinhadas pra comparar.
- **Um router por vez.** Os botões Todas, Railway, Hostinger e Sherlocker filtram os cards; setas e números trocam pelo teclado.
- **Três ordens.** Por provedor, mais livre primeiro ou expira primeiro. Router, ordem e período ficam lembrados.

## Correções

- **Contas desativadas com cota.** Elas aparecem apagadas no fim com as barras, como no painel; as removidas saem da grade.

## Instalar

```bash
git clone https://github.com/LucasOl1337/omarchy-9router-radar.git
cd omarchy-9router-radar
mkdir -p ~/.config/omarchy-9router-radar
cp routers.example.json ~/.config/omarchy-9router-radar/routers.json
# Configure seus routers antes de instalar.
python3 install.py
```

Quem já tem a v1.1.0: `git pull && python3 install.py`. A imagem usa dados fictícios.

## Verificado

11 testes Python e 9 testes Node passaram. Plugin validado, painel renderizado com dados reais e fictícios numa bancada, e versão carregada na barra conferida por diagnóstico IPC.
