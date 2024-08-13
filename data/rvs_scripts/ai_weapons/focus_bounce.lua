local userdata_table = mods.multiverse.userdata_table

-- Define bounce beams
local bounceBeams = {}
bounceBeams.RVS_FOCUS_BOUNCE = Hyperspace.Blueprints:GetWeaponBlueprint("RVS_PROJECTILE_FOCUS_BOUNCE")
bounceBeams.RVS_FOCUS_BOUNCE_CHAOS = Hyperspace.Blueprints:GetWeaponBlueprint("RVS_PROJECTILE_FOCUS_BOUNCE_CHAOS")
local bounceBeamProjectiles = {}
for _, bp in pairs(bounceBeams) do bounceBeamProjectiles[bp.name] = bp end

-- Handle firing of the weapon
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local bounceBeam = bounceBeams[weapon.blueprint.name]
    if bounceBeam then
        -- Replace fired projectiles with a damage-scaled beam
        local boost = weapon.queuedProjectiles:size()
        weapon.queuedProjectiles:clear()
        local beam = Hyperspace.App.world.space:CreateBeam(
            bounceBeam, projectile.position, projectile.currentSpace, projectile.ownerId,
            projectile.target, Hyperspace.Pointf(projectile.target.x, projectile.target.y + 1),
            projectile.destinationSpace, 1, projectile.heading)
        beam.damage.iDamage = beam.damage.iDamage + boost
        projectile:Kill()

        -- Play sound based on damage
        local soundName = (beam.damage.iDamage <= 2 and "ra_focusbeam" or "ra_focusbeambig")..tostring(math.random(3))
        Hyperspace.Sounds:PlaySoundMix(soundName, -1, false)
    end
end)

-- Handle reflections
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(ship, projectile, location, damage, newTile, beamHit)
    local bounceBeam = bounceBeamProjectiles[projectile and projectile.extend and projectile.extend.name]
    if bounceBeam then
        local projData = userdata_table(projectile, "mods.ai.bounceBeam")
        local reflectData = userdata_table(projectile, "mods.ai.reflectivePlating")
        if not projData.didBounce and not reflectData.reflect and damage.iDamage > 1 then
            -- Pick a target that isn't the hit room
            local graph = Hyperspace.ShipGraph.GetShipInfo(ship.iShipId)
            local room = math.random(0, graph.rooms:size() - 2)
            if room >= graph:GetSelectedRoom(location.x, location.y, true) then
                room = room + 1
            end
            local target = graph:GetRoomCenter(room)

            -- Create the reflected beam
            local beam = Hyperspace.App.world.space:CreateBeam(
                bounceBeam, location, ship.iShipId, projectile.ownerId,
                target, Hyperspace.Pointf(target.x, target.y + 1),
                ship.iShipId, 1, 0)
            beam.damage.iDamage = damage.iDamage - 1
            userdata_table(beam, "mods.ai.reflectivePlating").reflect = false
        end
        projData.didBounce = true
    end
end)
