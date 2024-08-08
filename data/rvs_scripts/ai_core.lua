if not mods or not mods.vertexutil then
    error("Couldn't find Vertex Tags and Utility Functions! Make sure it's above mods which depend on it in the Slipstream load order")
end

local vter = mods.multiverse.vter
local userdata_table = mods.multiverse.userdata_table
mods.rvsai = {}

-- Make a list of hologram crew that's easier to reference
mods.rvsai.holoSpecies = {}
local holoSpecies = mods.rvsai.holoSpecies
script.on_load(function()
    for holoName in vter(Hyperspace.Blueprints:GetBlueprintList("RVS_LIST_CREW_AI_AVATAR")) do
        holoSpecies[holoName] = true
    end
end)

-- Make a set of values
function mods.rvsai.make_set(tbl)
    local set = {}
    for _, e in ipairs(tbl) do set[e] = true end
    return set
end

-- Temporary drone spawner
function mods.rvsai.spawn_temp_drone(table)
    local name = table.name
    local ownerShip = table.ownerShip
    local targetShip = table.targetShip
    local targetLocation = table.targetLocation
    local shots = table.shots
    local position = table.position
    
    local drone = ownerShip:CreateSpaceDrone(Hyperspace.Blueprints:GetDroneBlueprint(name))
    drone.powerRequired = 0
    drone:SetMovementTarget(targetShip._targetable)
    drone:SetWeaponTarget(targetShip._targetable)
    drone.lifespan = shots or 2
    drone.powered = true
    drone:SetDeployed(true)
    drone.bDead = false
    if position then drone:SetCurrentLocation(position) end
    if targetLocation then drone.targetLocation = targetLocation end
    userdata_table(drone, "mods.ai.droneSwarm").clearOnJump = true
    return drone
end
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship.bJumping then
        for drone in vter(ship.spaceDrones) do
            if userdata_table(drone, "mods.ai.droneSwarm").clearOnJump then
                drone:SetDestroyed(true, false)
            end
        end
    end
end)
