local vter = mods.multiverse.vter
local userdata_table = mods.multiverse.userdata_table

-- Make a drone target enemy drones first before normal anti ship targetting
-- CV: I wrote this while I felt like crap and my brain was working at 0.1% capacity, god help whoever has to read it later
local function set_drone_destination(drone)
    local target = userdata_table(drone, "mods.ai.droneTarget").target
    if target then
        local shieldCenter = Hyperspace.ships(drone.currentSpace).ship:GetBaseEllipse().center
        drone.destinationLocation.x = (target.currentLocation.x - shieldCenter.x)*1.15 + shieldCenter.x
        drone.destinationLocation.y = (target.currentLocation.y - shieldCenter.y)*1.15 + shieldCenter.y
    end
end
local function aquire_drone_target(ship, droneName)
    local otherShip = Hyperspace.ships(1 - ship.iShipId)
    if otherShip then
        local target = nil
        for drone in vter(otherShip.spaceDrones) do
            if drone.deployed and drone.currentSpace == otherShip.iShipId and not drone.explosion.tracker.running and (drone.blueprint.typeName == "DEFENSE" or drone.blueprint.typeName == "SHIELD") then
                target = drone
                break
            end
        end
        for drone in vter(ship.spaceDrones) do
            if drone.blueprint and drone.blueprint.name == droneName then
                local targetTable = userdata_table(drone, "mods.ai.droneTarget")
                targetTable.target = target
                if target then
                    drone.targetLocation.x = target.currentLocation.x
                    drone.targetLocation.y = target.currentLocation.y
                    targetTable.targetingDrone = true
                elseif targetTable.targetingDrone then
                    drone.targetLocation = otherShip:GetRandomRoomCenter()
                    targetTable.targetingDrone = false
                end
                if drone.powered and not targetTable.poweredLastFrame then
                    set_drone_destination(drone)
                end
                targetTable.poweredLastFrame = drone.powered
            end
        end
    end
end
script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
    if drone.blueprint.name == "RVS_AI_MICROFIGHTER_INTERCEPTOR" then
        set_drone_destination(drone)
    end
end)
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if Hyperspace.ships.player then aquire_drone_target(Hyperspace.ships.player, "RVS_AI_MICROFIGHTER_INTERCEPTOR") end
    if Hyperspace.ships.enemy then aquire_drone_target(Hyperspace.ships.enemy, "RVS_AI_MICROFIGHTER_INTERCEPTOR") end
end)
