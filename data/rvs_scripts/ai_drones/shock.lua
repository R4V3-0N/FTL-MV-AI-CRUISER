local vter = mods.multiverse.vter

--Make a drone target systems only
local function retarget_drone_to_system(ship, droneName)
    local otherShip = Hyperspace.ships(1 - ship.iShipId)
    if otherShip then
        local otherShipGraph = Hyperspace.ShipGraph.GetShipInfo(otherShip.iShipId)
        for drone in vter(ship.spaceDrones) do
            if drone.blueprint.name == droneName then
                local targetRoom = otherShipGraph:GetSelectedRoom(drone.targetLocation.x, drone.targetLocation.y, true)
                if not otherShip:GetSystemInRoom(targetRoom) then
                    targetRoom = otherShip.vSystemList[Hyperspace.random32()%otherShip.vSystemList:size()].roomId
                    local targetRoomShape = otherShipGraph:GetRoomShape(targetRoom)
                    drone.targetLocation.x = targetRoomShape.x + targetRoomShape.w/2
                    drone.targetLocation.y = targetRoomShape.y + targetRoomShape.h/2
                end
            end
        end
    end
end
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if Hyperspace.ships.player then retarget_drone_to_system(Hyperspace.ships.player, "RVS_AI_MICROFIGHTER_SHOCK") end
    if Hyperspace.ships.enemy then retarget_drone_to_system(Hyperspace.ships.enemy, "RVS_AI_MICROFIGHTER_SHOCK") end
end)
