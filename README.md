# AWACS Auto-Respawn System for DCS World

Sistema avançado de respawn automático para aeronaves AWACS no DCS World usando o framework MOOSE.

## Características

### Funcionalidades Principais

- **Respawn Automático Infinito**: AWACS respawna automaticamente após ser destruído
- **Sistema de Escolta**: Suporte para escoltas de caças (opcional)
- **Menu F10 Interativo**: Consulta de informações em tempo real
- **Separação por Coalizão**: Cada lado vê apenas informações do seu próprio AWACS
- **Tratamento de Erros**: Validação robusta e logging detalhado
- **Estatísticas**: Rastreamento de spawns e destruições

### Recursos Avançados

- Configuração de TACAN e frequências de rádio
- Patrulha em órbita configurável
- Opção de imortalidade
- Respawn automático em caso de falha de motor
- Mensagens específicas por coalizão
- Callsigns personalizáveis

## Requisitos

- **DCS World** (versão compatível com MOOSE)
- **MOOSE Framework** instalado e carregado na missão

## Instalação

1. Certifique-se de que o MOOSE está carregado na sua missão
2. Copie o arquivo `Awacs_improved.lua` para a pasta da sua missão
3. No Mission Editor, adicione um gatilho:
   - **TYPE**: 4 MISSION START
   - **ACTION**: DO SCRIPT FILE
   - **FILE**: `Awacs_improved.lua`

## Configuração

### Templates Necessários no Mission Editor

Crie os seguintes grupos no Mission Editor:

#### AWACS Azul (BLUE)
- **Nome do Grupo**: `E-3A Anapa`
- **Tipo**: E-3A Sentry
- **Late Activation**: Ativado
- **Uncontrolled**: Desativado

#### AWACS Vermelho (RED)
- **Nome do Grupo**: `A50 Maykop`
- **Tipo**: A-50
- **Late Activation**: Ativado
- **Uncontrolled**: Desativado

#### Zonas de Patrulha
- **Zona Azul**: `Awacs_Blue`
- **Zona Vermelha**: `Awacs_Red`

### Escolta (Opcional)

Se desejar adicionar escoltas, crie os grupos:
- **BLUE**: `F-16 CAP Group`
- **RED**: `Mig29S Escolta`

E descomente as linhas `escortName` no script.

## Configuração Personalizada

### Parâmetros Disponíveis

```lua
{
    coalition    = "BLUE",           -- Coalizão: "BLUE" ou "RED"
    name         = "E-3A Anapa",     -- Nome do template no Mission Editor
    escortName   = "F-16 CAP Group", -- Nome da escolta (opcional)
    zoneName     = "Awacs_Blue",     -- Nome da zona de patrulha
    altitude     = 25000,            -- Altitude em pés
    speed        = 230,              -- Velocidade em knots
    heading      = 20,               -- Heading inicial em graus
    orbitRadius  = 40,               -- Raio da órbita em NM
    tacan        = { channel = 19, id = "DXS" }, -- Configuração TACAN
    radio        = 255,              -- Frequência de rádio em MHz
    delay        = 300,              -- Delay de respawn em segundos (5 min)
    engageRange  = 30,               -- Range de engajamento da escolta em NM
    callsign     = CALLSIGN.AWACS.Overlord, -- Callsign do AWACS
    immortal     = false,            -- AWACS indestrutível (true/false)
    respawnOnEngineShutdown = false  -- Respawn se motores desligarem
}
```

## Uso no Jogo

### Menu F10

Durante a missão, acesse o menu F10:

```
F10 → Outros Comandos → Informacoes AWACS
    ├── [Nome do AWACS]
    └── Frequencias Rapidas
```

### Informações Exibidas

Ao selecionar um AWACS, você verá:

```
===============================
AWACS: E-3A Anapa
===============================
Status: ATIVO

Radio: 255.000 MHz
TACAN: 19X DXS

Estatisticas:
   - Spawns: 1
   - Destruicoes: 0
===============================
```

### Frequências Rápidas

Exibe uma lista resumida de todos os AWACS da sua coalizão:

```
=============================
  FREQUENCIAS DOS AWACS
=============================
E-3A Anapa: Radio: 255.000 MHz | TACAN: 19X
=============================
```

## Mensagens do Sistema

### Mensagens Visíveis Apenas para Sua Coalizão

- **Spawn**: "BLUE AWACS - E-3A Anapa ativo | TACAN: 19X DXS | Rádio: 255.0 MHz"
- **Destruição**: "BLUE AWACS - E-3A Anapa foi destruído! Respawn em 5 minutos."
- **Escolta**: "BLUE escolta (F-16 CAP Group) protegendo AWACS."

## Funções de Controle (Avançado)

O script retorna um objeto com funções de controle:

```lua
-- Verificar número de spawns
local spawns = BlueAwacs.GetSpawnCount()

-- Verificar número de destruições
local destruicoes = BlueAwacs.GetDestroyCount()

-- Obter grupo ativo
local grupo = BlueAwacs.GetActiveGroup()

-- Parar o sistema de respawn
BlueAwacs.Stop()
```

## Estrutura de Arquivos

```
Scripts e projetos/
├── Awacs_improved.lua    # Script principal
└── README_AWACS.md       # Este arquivo
```

## Troubleshooting

### AWACS não spawna

1. Verifique se o MOOSE está carregado antes do script
2. Confirme que os nomes dos grupos no Mission Editor correspondem aos nomes no script
3. Verifique se as zonas foram criadas corretamente
4. Consulte o arquivo `dcs.log` para erros

### Menu F10 não aparece

1. Aguarde 5 segundos após o início da missão
2. Verifique se há erros no `dcs.log`
3. Confirme que o MOOSE está carregado

### Mensagens aparecem para a coalizão errada

1. Verifique se você está usando a versão mais recente do script
2. Confirme que o parâmetro `coalition` está correto na configuração

## Logs

O script gera logs detalhados no arquivo `dcs.log`:

```
[AWACS] Sistema de respawn automático iniciado para E-3A Anapa (delay: 300s)
[AWACS] E-3A Anapa spawnado (spawn #1)
[AWACS] Menu F10 criado com sucesso (separado por coalizao)
```

## Contribuindo

Sinta-se à vontade para:
- Reportar bugs
- Sugerir melhorias
- Fazer fork e modificar para suas necessidades

## Licença

Este script é fornecido "como está", sem garantias de qualquer tipo.

## Créditos

- **Framework**: [MOOSE](https://github.com/FlightControl-Master/MOOSE)
- **Desenvolvido para**: DCS World

## Changelog

### Versão Atual (Improved)

- ✅ Sistema de respawn automático infinito
- ✅ Menu F10 separado por coalizão
- ✅ Mensagens específicas por coalizão
- ✅ Tratamento robusto de erros
- ✅ Estatísticas de spawns e destruições
- ✅ Suporte para escolta (opcional)
- ✅ Configuração de imortalidade
- ✅ Logging detalhado

---

**Desenvolvido com ❤️ para a comunidade DCS**
