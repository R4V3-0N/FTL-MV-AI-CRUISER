local vter = mods.multiverse.vter

-- Custom drone orbit
-- Ported from escort duty mod
local escortEllipse = {
    center = {
        x = 203,
        y = 430
    }, 
    a = 172,
    b = 320
}
local droneSpeedFactor = 1.6
local activeDroneIds = {}

local calculate_coord_offset = function(angleFromCenter)
    local angleCos = escortEllipse.b*math.cos(angleFromCenter)
    local angleSin = escortEllipse.a*math.sin(angleFromCenter)
    local denom = math.sqrt(angleCos^2 + angleSin^2)
    return (escortEllipse.a*angleCos)/denom, (escortEllipse.b*angleSin)/denom
end

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    -- Iterate through all defense drones if the ship is AI renegade
    local isEscort = 0
    if pcall(function() isEscort = math.max(
            Hyperspace.ships.enemy:HasEquipment("SHIP RVSRB_AI_CRUISER_3_NORMAL"),
            Hyperspace.ships.enemy:HasEquipment("SHIP RVSRB_AI_CRUISER_3_CHALLENGE"),
            Hyperspace.ships.enemy:HasEquipment("SHIP RVSRB_AI_CRUISER_3_EXTREME"),
            Hyperspace.ships.enemy:HasEquipment("SHIP RVSRB_AI_CRUISER_3_CHAOS")
        ) end) and isEscort > 0 then
        local stillActive = {}
        for drone in vter(Hyperspace.ships.enemy.spaceDrones) do
            if drone.deployed and drone.blueprint.typeName == "DEFENSE" then
                stillActive[drone.selfId] = true
                local xOffset = nil
                local yOffset = nil
                
                -- Set drone location to a random point on the ellipse if just deployed
                if not activeDroneIds[drone.selfId] then
                    activeDroneIds[drone.selfId] = true
                    xOffset, yOffset = calculate_coord_offset((Hyperspace.random32()%360)*(math.pi/180))
                    drone:SetCurrentLocation(Hyperspace.Pointf(
                        escortEllipse.center.x + xOffset,
                        escortEllipse.center.y + yOffset))
                end

                -- Make the drone orbit the fake ellipse
                if drone.powered then
                    local lookAhead = drone.blueprint.speed*Hyperspace.FPS.SpeedFactor/droneSpeedFactor
                    xOffset, yOffset = calculate_coord_offset(math.atan(
                        drone.currentLocation.y - escortEllipse.center.y,
                        drone.currentLocation.x - escortEllipse.center.x))
                    local xIntersect = escortEllipse.center.x + xOffset
                    local yIntersect = escortEllipse.center.y + yOffset
                    local tanAngle = math.atan((escortEllipse.b^2/escortEllipse.a^2)*(xOffset/yOffset))
                    if (drone.currentLocation.y < escortEllipse.center.y) then
                        drone.destinationLocation = Hyperspace.Pointf(
                            xIntersect + lookAhead*math.cos(tanAngle),
                            yIntersect - lookAhead*math.sin(tanAngle))
                    else
                        drone.destinationLocation = Hyperspace.Pointf(
                            xIntersect - lookAhead*math.cos(tanAngle),
                            yIntersect + lookAhead*math.sin(tanAngle))
                    end
                end
            end
        end

        -- Clean out inactive drone IDs
        for droneId in pairs(activeDroneIds) do
            if not stillActive[droneId] then
                activeDroneIds[droneId] = nil
            end
        end
    end
end)
