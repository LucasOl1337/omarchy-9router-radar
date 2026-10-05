# Radar 9Router v1.1.0

5 de outubro de 2026

Todas as contas e a prioridade de uso num radar único.

## Novidades

- **Uma lista pros seus routers.** Contas, uso e conexões aparecem juntas. O ícone da barra é 9R.
- **Qual conta usar primeiro.** A cota livre ordena as opções, com renovação e estado da leitura.
- **Uso por período e rota.** Consulte Hoje, 7 dias, 30 dias e Total e veja onde usar a conta.

## Correções

- **Sem abas por domínio.** O radar reúne os routers e troca a versão da interface sem cache antigo.

## Sistemas

- **Instalação pra outros Omarchys.** Configure os routers e as credenciais por comando, variável ou SSH.

## Instalar

```bash
git clone https://github.com/LucasOl1337/omarchy-9router-radar.git
cd omarchy-9router-radar
mkdir -p ~/.config/omarchy-9router-radar
cp routers.example.json ~/.config/omarchy-9router-radar/routers.json
# Configure seus routers antes de instalar.
python3 install.py
```

O README explica as opções HTTP e SSH. A recomendação depende de cota recente disponível no provedor. Sem leitura válida, a conta fica sem recomendação. Um pedido encaminhado pode aparecer no uso de mais de um router; os registros ficam identificados por origem.

## Verificado

8 testes Python e 6 testes Node passaram. Plugin validado e versão carregada na barra conferida por diagnóstico IPC.
