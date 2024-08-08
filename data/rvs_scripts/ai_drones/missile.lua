--Number of shots a drone may fire before it is destroyed
local limitShots = {}
limitShots.RVS_COMBAT_MISSILE_1 = 7
limitShots.RVS_COMBAT_MISSILE_2 = 5
limitShots.RVS_COMBAT_MISSILE_3 = 15

--Implementation uses lifespan for save and load, replace with table implementation when saving features are available
--I think lifespan is only used for surge drones so it's ok to use here
script.on_internal_event(Defines.InternalEvents.DRONE_FIRE,
function(Projectile, Drone)
    local shots = limitShots[Drone.blueprint.name]
    --Lifespan incremented by base game code
    if shots then
        if Drone.lifespan == 2147483647 then
            Drone.lifespan = shots - 1
        elseif Drone.lifespan == 0 then
            Drone:BlowUp(false)
            Drone.lifespan = shots
        end
    end
    return Defines.Chain.CONTINUE
end)
