----------------------------------------------------------------
-- FUNCAO GENERICA PARA RESPAWN INFINITO DE AWACS + ESCOLTA
-- Versao melhorada com tratamento de erros e logging
-- https://github.com/GrInDmEtAl/AWACS-Improved
----------------------------------------------------------------

---@class AwacsConfig
---@field coalition string Coalizão ("BLUE" ou "RED")
---@field name string Nome do template do AWACS no Mission Editor
---@field escortName? string Nome do template da escolta (opcional)
---@field zoneName string Nome da zona de patrulha
---@field altitude? number Altitude em pés (padrão: 25000)
---@field speed? number Velocidade em knots (padrão: 320)
---@field heading? number Heading em graus (padrão: 300)
---@field orbitRadius? number Raio da órbita em NM (padrão: 30)
---@field tacan? table TACAN config {channel, id}
---@field radio? number Frequência de rádio em MHz
---@field delay? number Delay de respawn em segundos (padrão: 300)
---@field engageRange? number Range de engajamento da escolta em NM (padrão: 30)
---@field callsign? number Callsign do AWACS
---@field immortal? boolean Se true, AWACS não pode ser destruído (padrão: false)
---@field respawnOnEngineShutdown? boolean Respawn se motores forem desligados (padrão: false)

function AutoRespawnAwacsWithEscort(config)
    -- Validação de parâmetros obrigatórios
    if not config.name then
        env.error("AutoRespawnAwacsWithEscort: 'name' é obrigatório!")
        return
    end
    if not config.zoneName then
        env.error("AutoRespawnAwacsWithEscort: 'zoneName' é obrigatório!")
        return
    end
    if not config.coalition then
        env.error("AutoRespawnAwacsWithEscort: 'coalition' é obrigatório!")
        return
    end

    -- Parâmetros com valores padrão
    local delay        = config.delay or 300
    local engageRange  = config.engageRange or 30
    local altitude     = config.altitude or 25000
    local speed        = config.speed or 320
    local heading      = config.heading or 300
    local orbitRadius  = config.orbitRadius or 30
    local immortal     = config.immortal or false
    local respawnOnEngineShutdown = config.respawnOnEngineShutdown or false

    -- Contador de spawns (para estatísticas)
    local spawnCount = 0
    local destroyCount = 0

    -- Inicializa spawners
    local spawnEscort = config.escortName and SPAWN:New(config.escortName):InitLimit(2, 0) or nil
    local spawnAwacs  = SPAWN:New(config.name):InitLimit(1, 0)

    -- Referências para grupos ativos
    local activeAwacsGroup = nil
    local activeEscortGroup = nil

    -------------------------------------------------------------
    -- Função auxiliar: Criar missão AWACS
    -------------------------------------------------------------
    local function CreateAwacsMission(fg_awacs)
        local zone = ZONE:New(config.zoneName)
        if not zone then
            env.error("AutoRespawnAwacsWithEscort: Zona '" .. config.zoneName .. "' não encontrada!")
            return nil
        end

        local auf = AUFTRAG:NewAWACS(zone:GetCoordinate(), altitude, speed, heading, orbitRadius)
        
        if config.tacan then 
            auf:SetTACAN(config.tacan.channel, config.tacan.id) 
        end
        
        if config.radio then 
            auf:SetRadio(config.radio) 
        end

        return auf
    end

    -------------------------------------------------------------
    -- Função auxiliar: Spawnar escolta
    -------------------------------------------------------------
    local function SpawnEscort(fg_awacs)
        if not spawnEscort then return end

        local spawnedEscort = spawnEscort:Spawn()
        if spawnedEscort then
            activeEscortGroup = spawnedEscort
            local fg_escort = FLIGHTGROUP:New(spawnedEscort.GroupName)
            local escortAuf = AUFTRAG:NewESCORT(fg_awacs:GetGroup(), nil, engageRange)
            fg_escort:AddMission(escortAuf)

            local coalitionSide = config.coalition == "BLUE" and coalition.side.BLUE or coalition.side.RED
            MESSAGE:New(config.coalition .. " escolta (" .. config.escortName .. ") protegendo AWACS.", 10):ToCoalition(coalitionSide)
            env.info(string.format("[AWACS] Escolta %s spawnada para proteger %s", config.escortName, config.name))
        else
            env.warning("[AWACS] Falha ao spawnar escolta: " .. config.escortName)
        end
    end

    -------------------------------------------------------------
    -- Callback: Quando AWACS spawna
    -------------------------------------------------------------
    spawnAwacs:OnSpawnGroup(function(spawnedGroup)
        spawnCount = spawnCount + 1
        activeAwacsGroup = spawnedGroup

        env.info(string.format("[AWACS] %s spawnado (spawn #%d)", config.name, spawnCount))

        -- Cria FLIGHTGROUP
        local fg_awacs = FLIGHTGROUP:New(spawnedGroup.GroupName)
        fg_awacs:SetDefaultCallsign(config.callsign or CALLSIGN.AWACS.Focus, 5)

        -- Define imortalidade se configurado
        if immortal then
            spawnedGroup:SetImmortal(true)
            env.info(string.format("[AWACS] %s configurado como IMORTAL", config.name))
        end

        -- Cria missão AWACS
        local auf = CreateAwacsMission(fg_awacs)
        if auf then
            fg_awacs:AddMission(auf)
        else
            env.error("[AWACS] Falha ao criar missão para " .. config.name)
            return
        end

        -- Mensagem de ativação
        local coalitionSide = config.coalition == "BLUE" and coalition.side.BLUE or coalition.side.RED
        local tacanInfo = config.tacan and string.format(" | TACAN: %dX %s", config.tacan.channel, config.tacan.id) or ""
        local radioInfo = config.radio and string.format(" | Rádio: %.1f MHz", config.radio) or ""
        MESSAGE:New(config.coalition .. " AWACS - " .. config.name .. " ativo" .. tacanInfo .. radioInfo, 15):ToCoalition(coalitionSide)

        -- Spawna escolta
        SpawnEscort(fg_awacs)

        -- Monitor de destruição usando handler global de eventos (mais confiável)
        local awacsGroupName = spawnedGroup.GroupName
        local DeadEventHandler = {}
        function DeadEventHandler:onEvent(event)
            if event.id == world.event.S_EVENT_DEAD or event.id == world.event.S_EVENT_CRASH then
                if event.initiator and event.initiator.getGroup then
                    -- Pega o grupo da unidade destruída
                    local unit = event.initiator
                    local unitGroup = unit:getGroup()
                    
                    if unitGroup and unitGroup:getName() == awacsGroupName then
                        destroyCount = destroyCount + 1
                        local coalitionSide = config.coalition == "BLUE" and coalition.side.BLUE or coalition.side.RED
                        env.info(string.format("[AWACS] %s DESTRUIDO (destruicoes: %d) - Respawn em %d segundos", 
                            config.name, destroyCount, delay))
                        MESSAGE:New(config.coalition .. " AWACS - " .. config.name .. " foi destruido! Respawn em " .. 
                            math.floor(delay/60) .. " minutos.", 15):ToCoalition(coalitionSide)
                        
                        -- Remove o handler após detectar destruição
                        world.removeEventHandler(DeadEventHandler)
                    end
                end
            end
        end
        world.addEventHandler(DeadEventHandler)

        -- Monitor de engine shutdown (opcional)
        if respawnOnEngineShutdown then
            local EngineEventHandler = {}
            function EngineEventHandler:onEvent(event)
                if event.id == world.event.S_EVENT_ENGINE_SHUTDOWN then
                    if event.initiator and event.initiator.getGroup then
                        local unit = event.initiator
                        local unitGroup = unit:getGroup()
                        
                        if unitGroup and unitGroup:getName() == awacsGroupName then
                            env.warning(string.format("[AWACS] %s motores desligados - Forcando respawn", config.name))
                            spawnedGroup:Destroy()
                            world.removeEventHandler(EngineEventHandler)
                        end
                    end
                end
            end
            world.addEventHandler(EngineEventHandler)
        end
    end)

    -------------------------------------------------------------
    -- Respawn automático (loop infinito)
    -------------------------------------------------------------
    spawnAwacs:SpawnScheduled(delay, 0.1)

    env.info(string.format("[AWACS] Sistema de respawn automático iniciado para %s (delay: %ds)", 
        config.name, delay))

    -- Retorna tabela com funções de controle
    return {
        GetSpawnCount = function() return spawnCount end,
        GetDestroyCount = function() return destroyCount end,
        GetActiveGroup = function() return activeAwacsGroup end,
        GetActiveEscort = function() return activeEscortGroup end,
        Stop = function() 
            spawnAwacs:Stop()
            env.info("[AWACS] Sistema de respawn parado para " .. config.name)
        end
    }
end

----------------------------------------------------------------
-- AWACS AZUL (BLUE)
----------------------------------------------------------------
local BlueAwacs = AutoRespawnAwacsWithEscort({
    coalition    = "BLUE",
    name         = "E-3A Anapa",
    -- escortName   = "F-16 CAP Group",  -- Descomente se quiser escolta
    zoneName     = "Awacs_Blue",
    altitude     = 25000,
    speed        = 230,
    heading      = 20,
    orbitRadius  = 40,
    tacan        = { channel = 19, id = "DXS" },
    radio        = 255,
    delay        = 300,   -- 5 min
    engageRange  = 30,
    callsign     = CALLSIGN.AWACS.Overlord,
    immortal     = false,  -- Mude para true se quiser AWACS indestrutível
    respawnOnEngineShutdown = false
})

----------------------------------------------------------------
-- AWACS VERMELHO (RED)
----------------------------------------------------------------
local RedAwacs = AutoRespawnAwacsWithEscort({
    coalition    = "RED",
    name         = "A50 Maykop",
    -- escortName   = "Mig29S Escolta",  -- Descomente se quiser escolta
    zoneName     = "Awacs_Red",
    altitude     = 25000,
    speed        = 250,
    heading      = 40,
    orbitRadius  = 55,
    tacan        = { channel = 29, id = "DXS" },
    radio        = 225,
    delay        = 300,   -- 5 min
    engageRange  = 32,
    callsign     = CALLSIGN.AWACS.Focus,
    immortal     = false,
    respawnOnEngineShutdown = false
})

----------------------------------------------------------------
-- COMANDOS DE MONITORAMENTO (opcional)
----------------------------------------------------------------
-- Exemplo de uso: verificar estatísticas
-- env.info("Blue AWACS spawns: " .. BlueAwacs.GetSpawnCount())
-- env.info("Red AWACS destruições: " .. RedAwacs.GetDestroyCount())

-- Para parar o respawn (se necessário):
-- BlueAwacs.Stop()
-- RedAwacs.Stop()

----------------------------------------------------------------
-- SISTEMA DE MENU F10 - INFORMACOES DOS AWACS
----------------------------------------------------------------

-- Tabela global para armazenar configurações dos AWACS
_G.AwacsRegistry = _G.AwacsRegistry or {}

---Registra um AWACS no sistema de menu F10
---@param config AwacsConfig Configuração do AWACS
---@param controller table Objeto de controle retornado pela função AutoRespawnAwacsWithEscort
function RegisterAwacsInMenu(config, controller)
    table.insert(_G.AwacsRegistry, {
        config = config,
        controller = controller
    })
end

-- Registra os AWACS criados
RegisterAwacsInMenu({
    coalition    = "BLUE",
    name         = "E-3A Anapa",
    zoneName     = "Awacs_Blue",
    altitude     = 25000,
    speed        = 230,
    tacan        = { channel = 19, id = "DXS" },
    radio        = 255,
    callsign     = CALLSIGN.AWACS.Overlord
}, BlueAwacs)

RegisterAwacsInMenu({
    coalition    = "RED",
    name         = "A50 Maykop",
    zoneName     = "Awacs_Red",
    altitude     = 25000,
    speed        = 250,
    tacan        = { channel = 29, id = "DXS" },
    radio        = 225,
    callsign     = CALLSIGN.AWACS.Focus
}, RedAwacs)

---Formata informações de um AWACS para exibição
---@param awacsData table Dados do AWACS registrado
---@return string Texto formatado
local function FormatAwacsInfo(awacsData)
    local cfg = awacsData.config
    local ctrl = awacsData.controller
    
    local info = {}
    table.insert(info, "==============================")
    table.insert(info, "AWACS: " .. cfg.name)
    table.insert(info, "===============================")
    
    -- Status
    local activeGroup = ctrl.GetActiveGroup()
    if activeGroup and activeGroup:IsAlive() then
        table.insert(info, "Status: ATIVO")
    else
        table.insert(info, "Status: INATIVO")
    end
    
    table.insert(info, "")
    
    -- Comunicações
    if cfg.radio then
        table.insert(info, "Radio: " .. string.format("%.3f MHz", cfg.radio))
    end
    
    if cfg.tacan then
        table.insert(info, "TACAN: " .. cfg.tacan.channel .. "X " .. cfg.tacan.id)
    end
    
    table.insert(info, "")
    
    -- Estatísticas
    table.insert(info, "Estatisticas:")
    table.insert(info, "   - Spawns: " .. ctrl.GetSpawnCount())
    table.insert(info, "   - Destruicoes: " .. ctrl.GetDestroyCount())
    
    table.insert(info, "===============================")
    
    return table.concat(info, "\n")
end

---Cria menu F10 para informações de AWACS (separado por coalizão)
local function CreateAwacsF10Menu()
    -- Menu principal para BLUE
    local blueMainMenu = MENU_COALITION:New(coalition.side.BLUE, "Informacoes AWACS")
    
    -- Menu principal para RED
    local redMainMenu = MENU_COALITION:New(coalition.side.RED, "Informacoes AWACS")
    
    -- Adiciona comandos para cada AWACS registrado (apenas para sua coalizão)
    for _, awacsData in ipairs(_G.AwacsRegistry) do
        local cfg = awacsData.config
        local targetMenu = cfg.coalition == "BLUE" and blueMainMenu or redMainMenu
        local coalitionSide = cfg.coalition == "BLUE" and coalition.side.BLUE or coalition.side.RED
        
        -- Comando individual para cada AWACS (visível apenas para sua coalizão)
        MENU_COALITION_COMMAND:New(
            coalitionSide,
            cfg.name,
            targetMenu,
            function()
                local info = FormatAwacsInfo(awacsData)
                MESSAGE:New(info, 30):ToCoalition(coalitionSide)
            end
        )
    end
    
    -- Comando para informações rápidas (apenas frequências) - por coalizão
    for _, awacsData in ipairs(_G.AwacsRegistry) do
        local cfg = awacsData.config
        local targetMenu = cfg.coalition == "BLUE" and blueMainMenu or redMainMenu
        local coalitionSide = cfg.coalition == "BLUE" and coalition.side.BLUE or coalition.side.RED
        
        -- Adiciona apenas uma vez por coalizão
        local menuName = "Frequencias Rapidas"
        if not _G["AwacsQuickInfoAdded_" .. cfg.coalition] then
            _G["AwacsQuickInfoAdded_" .. cfg.coalition] = true
            
            MENU_COALITION_COMMAND:New(
                coalitionSide,
                menuName,
                targetMenu,
                function()
                    local quickInfo = {}
                    table.insert(quickInfo, "=============================")
                    table.insert(quickInfo, "  FREQUENCIAS DOS AWACS")
                    table.insert(quickInfo, "=============================")
                    
                    -- Mostra apenas AWACS da mesma coalizão
                    for _, data in ipairs(_G.AwacsRegistry) do
                        if data.config.coalition == cfg.coalition then
                            local c = data.config
                            local line = c.name .. ":"
                            
                            if c.radio then
                                line = line .. " Radio: " .. string.format("%.3f MHz", c.radio)
                            end
                            
                            if c.tacan then
                                line = line .. " | TACAN: " .. c.tacan.channel .. "X"
                            end
                            
                            table.insert(quickInfo, line)
                        end
                    end
                    
                    table.insert(quickInfo, "=============================")
                    
                    MESSAGE:New(table.concat(quickInfo, "\n"), 20):ToCoalition(coalitionSide)
                end
            )
        end
    end
    
    env.info("[AWACS] Menu F10 criado com sucesso (separado por coalizao)")
end

-- Cria o menu F10 após 5 segundos (garante que tudo está carregado)
SCHEDULER:New(nil, CreateAwacsF10Menu, {}, 5)

env.info("[AWACS] Sistema de menu F10 inicializado")
