local userdata_table = mods.multiverse.userdata_table
local spawn_temp_drone = mods.rvsai.spawn_temp_drone

-- Spawn children for swarm drone
local shotsToSpawn = 2 -- Spawn a drone every shotsToSpawn shots
script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
    if drone.blueprint.name == "RVS_AI_MICROFIGHTER_SWARM" then
        local swarmData = userdata_table(drone, "mods.ai.droneSwarm")
        swarmData.shots = (swarmData.shots or shotsToSpawn) - 1
        if swarmData.shots <= 0 then
            swarmData.shots = shotsToSpawn
            local thisShip = Hyperspace.ships(drone.iShipId)
            local otherShip = Hyperspace.ships(1 - drone.iShipId)
            spawn_temp_drone{name = "RVS_AI_MICROFIGHTER_SWARM_CHILD", ownerShip = thisShip, targetShip = otherShip}
        end
    end
    return Defines.Chain.CONTINUE
end)
