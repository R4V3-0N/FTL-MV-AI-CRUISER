local vter = mods.multiverse.vter

-- Make beam defense drone fire beam and destroy projectile
script.on_internal_event(Defines.InternalEvents.DRONE_FIRE,
function(Projectile, Drone)
    if Drone.blueprint.name == "RVS_BEAM_DEFENSE_1" then
        local spaceManager = Hyperspace.App.world.space
        --Spawn beam from drone to target
        spaceManager:CreateBeam(
            Hyperspace.Blueprints:GetWeaponBlueprint("RVS_BEAM_DEFENSE_SHOT"), 
            Drone.currentLocation, 
            Projectile.currentSpace,
            1 - Projectile.ownerId,
            Projectile.target, 
            Hyperspace.Pointf(Projectile.target.x, Projectile.target.y + 1),
            Projectile.currentSpace, 
            1, 
            -1)
        --Destroy target (Beam is not programmed to do so in base game)
        for target in vter(spaceManager.projectiles) do
            if target:GetSelfId() == Drone.currentTargetId then
                target.death_animation:Start(true)
                break
            end
        end
        
        return Defines.Chain.PREEMPT
    end
    return Defines.Chain.CONTINUE
end)
