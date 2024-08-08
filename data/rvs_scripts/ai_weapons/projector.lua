local vter = mods.multiverse.vter

-- RVS_PROJECTOR_AVATAR implementation
local get_random_ship_system = function(ship)
    local systems = {}
    for system in vter(ship.vSystemList) do
        table.insert(systems, system:GetRoomId())
    end
    return systems[math.random(#systems)]
end

local refresh_boarding_AI = function(targetShip)
    local assaultCount = 2
    local decoyCount = 2
    for crewmen in vter(targetShip.vCrewList) do
        if crewmen.blueprint.name == "rvs_ai_hologram_assault" then
            crewmen.extend.deathTimer:Start(30) --Reset their death Time
            crewmen.health.first = crewmen.health.second --Reset their health
            assaultCount = assaultCount - 1
        end
        if crewmen.blueprint.name == "rvs_ai_hologram_decoy" then
            crewmen.extend.deathTimer:Start(30) --Reset their death Time
            crewmen.health.first = crewmen.health.second --Reset their health
            decoyCount = decoyCount - 1
        end
        if crewmen.blueprint.name == "rvs_ai_hologram" then
            crewmen.health.first = crewmen.health.second --Reset their health
            decoyCount = decoyCount - 1
        end
    end

    local worldManager = Hyperspace.App.world
    local eventParser = Hyperspace.CustomEventsParser.GetInstance()

    if targetShip.iShipId == 1 then
        if assaultCount == 2 and decoyCount == 2 then
            eventParser:LoadEvent(worldManager,"RVS_PROJECTOR_SPAWN_DECOYATTACKER",false,-1)
            return end

        for i = 0, assaultCount - 1 do
            eventParser:LoadEvent(worldManager,"RVS_PROJECTOR_SPAWN_ATTACKER_SINGLE",false,-1)
        end
        for i = 0, decoyCount - 1 do
            eventParser:LoadEvent(worldManager,"RVS_PROJECTOR_SPAWN_DECOY_SINGLE",false,-1)
        end
    else
        if assaultCount == 2 and decoyCount == 2 then
            eventParser:LoadEvent(worldManager,"RVS_PROJECTOR_ENEMY_SPAWN_DECOYATTACKER",false,-1)
            return end

        for i = 0, assaultCount - 1 do
            eventParser:LoadEvent(worldManager,"RVS_PROJECTOR_ENEMY_SPAWN_ATTACKER_SINGLE",false,-1)
        end
        for i = 0, decoyCount - 1 do
            eventParser:LoadEvent(worldManager,"RVS_PROJECTOR_ENEMY_SPAWN_DECOY_SINGLE",false,-1)
        end
    end
    
end

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, 
function(shipManager, projectile, location, Damage, shipFriendlyFire)
    if projectile and projectile.extend.name == "RVS_PROJECTOR_AVATAR" then
        refresh_boarding_AI(shipManager)
    end
    return Defines.Chain.CONTINUE
end)

-- Small buff/debuff applied on evasion while projector is active, only for the player
script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR, 
function(shipManager, value)
    local playerShip = Hyperspace.ships.player
    if not playerShip or not playerShip.weaponSystem then return end
    for weapon in vter(playerShip.weaponSystem.weapons) do
        if weapon.blueprint.name == "RVS_PROJECTOR_AVATAR" and weapon.powered then
            if shipManager.iShipId == 0 then
                value = value + 5
            else
                value = value - 5
            end
        end
    end
    return Defines.Chain.CONTINUE, value
end)

-- Pre-half ignited projector for the player on jump
script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, 
function(shipManager)
    if not shipManager.iShipId == 1 then return end
    for weapon in vter(shipManager.weaponSystem.weapons) do
        if weapon.blueprint.name == "RVS_PROJECTOR_AVATAR" and weapon.powered then
            weapon.cooldown.first = weapon.cooldown.second/2
        end
    end
end)

-- Player method
script.on_game_event("RVS_PROJECTOR_SPAWN_DELAY", false, function()
    local shipManager = Hyperspace.ships.player
    local shipOpponent = Hyperspace.ships.enemy
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.blueprint.name == "rvs_ai_hologram_decoy" or crewmem.blueprint.name == "rvs_ai_hologram_assault" then
            local tpRoomId = get_random_ship_system(shipOpponent)
            local deathTime = Hyperspace.TimerHelper()
            deathTime:Start(30)
            crewmem.extend.deathTimer = deathTime
            if not pcall(function() crewmem.extend:InitiateTeleport(1, tpRoomId, 0) end) then
                crewmem:Kill(true)
            end
        end
    end
end)

-- Enemy method
script.on_game_event("RVS_PROJECTOR_ENEMY_SPAWN_DELAY", false, function()
    local shipManager = Hyperspace.ships.enemy
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.blueprint.name == "rvs_ai_hologram_decoy" or crewmem.blueprint.name == "rvs_ai_hologram_assault" then
            local deathTime = Hyperspace.TimerHelper()
            deathTime:Start(30)
            crewmem.extend.deathTimer = deathTime
        end
    end
end)
