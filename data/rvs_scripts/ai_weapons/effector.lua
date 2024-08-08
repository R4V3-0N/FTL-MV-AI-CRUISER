local vter = mods.multiverse.vter
local make_set = mods.rvsai.make_set
local function pop_random(_table)
    return table.remove(_table, math.random(#_table))
end

-- Make enemy effectors target only systems
local systemTargetWeapons = {}
local sysWeights = {}
sysWeights.weapons = 6
sysWeights.shields = 6
sysWeights.pilot = 3
sysWeights.engines = 3
sysWeights.teleporter = 2
sysWeights.hacking = 2
sysWeights.medbay = 2
sysWeights.clonebay = 2
systemTargetWeapons.RA_EFFECTOR_1 = sysWeights
systemTargetWeapons.RA_EFFECTOR_2 = sysWeights
systemTargetWeapons.RA_EFFECTOR_HEAVY = sysWeights
systemTargetWeapons.RA_EFFECTOR_CHAIN = sysWeights
systemTargetWeapons.RVS_ARTILLERY_EFFECTOR = sysWeights
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local thisShip = Hyperspace.ships(weapon.iShipId)
    local otherShip = Hyperspace.ships(1 - weapon.iShipId)
    local sysWeights = systemTargetWeapons[weapon.blueprint.name]
    if thisShip and otherShip and (thisShip.iShipId == 1 or weapon.isArtillery) and sysWeights then
        local sysTargets = {}
        local weightSum = 0
        
        -- Collect all player systems and their weights
        for system in vter(otherShip.vSystemList) do
            local sysId = system:GetId()
            if otherShip:HasSystem(sysId) then
                local weight = sysWeights[Hyperspace.ShipSystem.SystemIdToName(sysId)] or 1
                if weight > 0 then
                    weightSum = weightSum + weight
                    table.insert(sysTargets, {
                        id = sysId,
                        weight = weight
                    })
                end
            end
        end
        
        -- Pick a random system using the weights
        if #sysTargets > 0 then
            local rnd = math.random(weightSum);
            for i = 1, #sysTargets do
                if rnd <= sysTargets[i].weight then
                    projectile.target = otherShip:GetRoomCenter(otherShip:GetSystemRoom(sysTargets[i].id))
                    projectile:ComputeHeading()
                    return
                end
                rnd = rnd - sysTargets[i].weight
            end
            error("Weighted selection error - reached end of options without making a choice!")
        end
    end
end)

--Effector Artillery
--Rules:
--Never target the same room twice, unless the ship has less than 3 rooms
--Always target systems, unless the ship has less than 3 systems
--Always target a defensive, offensive, and "other" system, unless the ship does not have a system to fit one or more of said categories
local defensiveSystemIds = make_set{0, 1, 6, 10}
local offensiveSystemIds = make_set{3, 4, 9, 11, 14, 15}
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE,
function(projectile, weapon)
    if weapon.blueprint.name == "RVS_ARTILLERY_AI" and weapon.queuedProjectiles:size() == 2 then --Target projectiles when first projectile fires
        local ship = Hyperspace.ships(projectile.targetId)
        local roomList = ship.ship.vRoomList
        local defensive, offensive, other, empty = {}, {}, {}, {} --Create target candidate tables
        for roomID = 0, Hyperspace.ShipGraph.GetShipInfo(projectile.targetId):RoomCount() - 1 do
            local system = ship:GetSystemInRoom(roomID)
            if not system then
                table.insert(empty, roomID) --List of systemless room IDs
            elseif defensiveSystemIds[system:GetId()] then
                table.insert(defensive, roomID) --List of defensive system room IDs
            elseif offensiveSystemIds[system:GetId()] then
                table.insert(offensive, roomID) --List of offensive system room IDs
            else
                table.insert(other, roomID) --List of other system room IDs
            end
        end
        projectile.target = ship:GetRoomCenter(pop_random(defensive) or pop_random(offensive) or pop_random(other) or pop_random(empty) or 0) --Prioritize defensive systems, then systems, then empty rooms
        weapon.queuedProjectiles[0].target = ship:GetRoomCenter(pop_random(offensive) or pop_random(other) or pop_random(defensive) or pop_random(empty) or 0) --Prioritize offensive systems, then systems, then empty rooms
        weapon.queuedProjectiles[1].target = ship:GetRoomCenter(pop_random(other) or pop_random(defensive) or pop_random(offensive) or pop_random(empty) or 0) --Prioritize other systems, then systems, then empty rooms
    end
end)
