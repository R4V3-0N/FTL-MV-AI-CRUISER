local spawn_temp_drone = mods.rvsai.spawn_temp_drone

--RVS_AI_SWARM implementation
--Spawn drone when drone is destroyed
local swarmChildProj = Hyperspace.Blueprints:GetWeaponBlueprint("RVS_AI_MICROFIGHTER_SWARM_CHILD_PROJ_DUMMY")
script.on_internal_event(Defines.InternalEvents.DRONE_COLLISION,
function(Drone, Projectile, Damage, CollisionResponse)
    local thisShip = Hyperspace.ships(Drone.iShipId)
    local otherShip = Hyperspace.ships(1 - Drone.iShipId)
    if thisShip and otherShip and Damage.iIonDamage <= 0 and Damage.iDamage > 0 and otherShip:HasAugmentation("RVS_AI_SWARM") > 0 then --If drone would be destroyed and ship has drone spawning aug
        --Spawn drone at drone's location, or if the drone is in the other ship's space, spawn a projectile that will become the drone
        if thisShip.iShipId == Drone.currentSpace then
            spawn_temp_drone{name = "RVS_AI_MICROFIGHTER_SWARM_CHILD", ownerShip = otherShip, targetShip = thisShip, position = Drone.currentLocation}
        else
            local spaceManager = Hyperspace.App.world.space
            local shipCenter = otherShip._targetable:GetShieldShape().center
            local heading = math.deg(math.atan(Drone.currentLocation.y - shipCenter.y, Drone.currentLocation.x - shipCenter.x))
            spaceManager:CreateMissile(swarmChildProj, Drone.currentLocation, Drone.currentSpace, Projectile.ownerId, thisShip:GetRandomRoomCenter(), Drone.iShipId, heading)
        end
    end
    return Defines.Chain.CONTINUE
end)
script.on_internal_event(Defines.InternalEvents.PROJECTILE_PRE, function(projectile)
    if projectile.extend.name == "RVS_AI_MICROFIGHTER_SWARM_CHILD_PROJ_DUMMY" and projectile.ownerId ~= projectile.currentSpace then
        local ship = Hyperspace.ships(projectile.ownerId)
        local otherShip = Hyperspace.ships(1 - projectile.ownerId)
        if ship and otherShip then
            spawn_temp_drone{name = "RVS_AI_MICROFIGHTER_SWARM_CHILD", ownerShip = ship, targetShip = otherShip, position = projectile.position}
        end
        projectile:Kill()
    end
end)

--V: Should this trigger on resist? Leaving like this for now unless told otherwise.
local function drone_vengeance(ship, damage)
    local rolledVengeance = math.random(100) <= 15 --15% chance
    if damage.iDamage > 0 and ship:HasAugmentation("RVS_AI_SWARM") > 0 and rolledVengeance then
        local otherShip = Hyperspace.ships(1 - ship.iShipId)
        spawn_temp_drone{name = "RVS_AI_MICROFIGHTER_SWARM_CHILD", ownerShip = ship, targetShip = otherShip}
    end
end
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, 
function(ship, projectile, location, damage, shipFriendlyFire)
    drone_vengeance(ship, damage)
    return Defines.Chain.CONTINUE
end, -1000) --Allow other functions to modify parameters first

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM,
function(ship, projectile, location, damage, newTile, beamHit)
    if beamHit == Defines.BeamHit.NEW_ROOM then
        drone_vengeance(ship, damage)   
    end
    return Defines.Chain.CONTINUE, beamHit
end, -1000) --Allow other functions to modify parameters first
