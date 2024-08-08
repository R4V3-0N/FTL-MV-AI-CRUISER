local vter = mods.multiverse.vter
local userdata_table = mods.multiverse.userdata_table
local time_increment = mods.multiverse.time_increment

local function check_paused()
    return Hyperspace.App.gui.bPaused or Hyperspace.App.gui.menu_pause or Hyperspace.App.gui.event_pause
end
local function beam_pierces_shield(beam)
    local target = Hyperspace.ships(beam.targetId)
    if not target then return false end
    if not target.shieldSystem then return true end
    if target.shieldSystem.shields.power.super.first > 0 then return false end
    return beam.damage.iDamage + beam.damage.iShieldPiercing > target.shieldSystem.shields.power.first
end
local function transfer_damage(damageDest, damageSource)
    damageDest.iDamage = damageSource.iDamage
    damageDest.iShieldPiercing = damageSource.iShieldPiercing
    damageDest.fireChance = damageSource.fireChance
    damageDest.breachChance = damageSource.breachChance
    damageDest.stunChance = damageSource.stunChance
    damageDest.iIonDamage = damageSource.iIonDamage
    damageDest.iSystemDamage = damageSource.iSystemDamage
    damageDest.iPersDamage = damageSource.iPersDamage
    damageDest.bHullBuster = damageSource.bHullBuster
    damageDest.bLockdown = damageSource.bLockdown
    damageDest.crystalShard = damageSource.crystalShard
    damageDest.bFriendlyFire = damageSource.bFriendlyFire
    damageDest.iStun = damageSource.iStun
end

-- Custom damage message logic
local customDamageMessages = {}
local function create_damage_message(shipId, sprite, x, y)
    table.insert(customDamageMessages, {
        shipId = shipId,
        sprite = sprite,
        x = math.random(21) - 11 + x,
        y = y - 30,
        lifetime = 1
    })
end
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if not check_paused() then
        local messageCount = #customDamageMessages
        local index = 1
        while index <= messageCount do
            local damageMessage = customDamageMessages[index]
            damageMessage.lifetime = damageMessage.lifetime - time_increment()
            if damageMessage.lifetime <= 0 then
                table.remove(customDamageMessages, index)
                messageCount = messageCount - 1
            else
                index = index + 1
            end
        end
    end
end)
script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function() end, function(ship)
    for _, damageMessage in ipairs(customDamageMessages) do
        if damageMessage.shipId == ship.iShipId then
            Graphics.CSurface.GL_PushMatrix()
            Graphics.CSurface.GL_Translate(damageMessage.x, damageMessage.y - 10*(1 - damageMessage.lifetime))
            Graphics.CSurface.GL_RenderPrimitive(damageMessage.sprite)
            Graphics.CSurface.GL_PopMatrix()
        end
    end
end)

-- Reflection logic
script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(ship)
    if ship.iShipId == 0 and ship:HasEquipment("RVS_REFLECTIVE_PLATING") > 0 then
        -- Reset reflective plating power
        Hyperspace.playerVariables.loc_ai_reflect_power = 0
    end
end)
do
    -- Modded beams with unusual logic that doesn't pair well with the reflection logic
    local reflectionExceptions = {
        "AA_BEAM_SUSTAIN"
    }
    script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, bp)
        local targetShip = Hyperspace.ships(projectile.targetId)
        if bp.typeName == "BEAM" and targetShip and targetShip:HasEquipment("RVS_REFLECTIVE_PLATING") > 0 then   
            -- Ignore beams in the exception list
            for _, exception in ipairs(reflectionExceptions) do
                if bp.name == exception then return end
            end
            
            -- Make beam pierce all shields on player ship
            local originalSp
            if projectile.targetId == 0 then
                originalSp = projectile.damage.iShieldPiercing
                projectile.damage.iShieldPiercing = 11
            end
            
            -- Roll reflection chance
            local doReflection = false
            if projectile.targetId == 0 then
                -- Based on augment power on player ship
                local reflectPower = Hyperspace.playerVariables.loc_ai_reflect_power
                doReflection = reflectPower >= projectile.damage.iDamage or math.random() < reflectPower/projectile.damage.iDamage
            else
                -- Flat reflection chance for all beams on enemy ship
                doReflection = math.random() < targetShip:GetAugmentationValue("RVS_REFLECTIVE_PLATING")
            end
            if doReflection then
                -- Set up reflection data
                local reflectData = userdata_table(projectile, "mods.ai.reflectivePlating")
                reflectData.reflect = true
                reflectData.justHit = true
                reflectData.angleSign = math.random(2)*2 - 3
                reflectData.angle = math.random(360)
                reflectData.thickness = 6*math.max(1, projectile.damage.iDamage)
                reflectData.sp = originalSp
                reflectData.damage = Hyperspace.Damage()
            end
        end
    end)
end
do
    -- Origin position for reflected beams outside the visible area
    local farPoint = Hyperspace.Pointf(-800, -800)

    -- Sprite for "REFLECT" damage message
    local reflectTex = Hyperspace.Resources:GetImageId("numbers/text_reflect.png")
    local reflectPrimitive = Hyperspace.Resources:CreateImagePrimitive(reflectTex, -reflectTex.width/2, -reflectTex.height/2, 0, 
Graphics.GL_Color(1, 1, 1, 1), 1.0, false)

    script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(ship, projectile, location, damage, newTile, beamHit)
        local reflectData = userdata_table(projectile, "mods.ai.reflectivePlating")
        if reflectData.reflect then
            -- Logic for when the ship is first hit by a reflected beam
            if reflectData.justHit then
                reflectData.justHit = false
                
                -- Show "REFLECT" damage message
                create_damage_message(ship.iShipId, reflectPrimitive, location.x, location.y)
                
                -- Create duplicate beam to fire on the other ship
                local ownerShip = Hyperspace.ships(projectile.ownerId)
                if ownerShip then
                    local bp = Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name)
                    
                    -- Randomly pick two different rooms and draw
                    -- a line from the center of one to the other
                    local graph = Hyperspace.ShipGraph.GetShipInfo(projectile.ownerId)
                    local target1 = math.random(graph.rooms:size()) - 1
                    local target2 = math.random(graph.rooms:size() - 1)
                    if target2 <= target1 then target2 = target2 - 1 end
                    target1 = graph:GetRoomCenter(graph.rooms[target1].iRoomId)
                    target2 = graph:GetRoomCenter(graph.rooms[target2].iRoomId)
                    local swipeAngle = math.atan(target1.y - target2.y, target1.x - target2.x) + math.pi
                    target2.x = bp.length*math.cos(swipeAngle) + target1.x
                    target2.y = bp.length*math.sin(swipeAngle) + target1.y

                    -- Create the reflected beam
                    local spawnedBeam = Hyperspace.App.world.space:CreateBeam(bp, farPoint, projectile.targetId, projectile.targetId, target1, target2, projectile.ownerId, bp.length, 0)
                    
                    -- Conform damage of reflected beam to damage of source beam
                    transfer_damage(spawnedBeam.damage, damage)
                    if reflectData.sp then spawnedBeam.damage.iShieldPiercing = reflectData.sp end
                    
                    -- Set up reflection table for reflected beam
                    reflectData.spawnId = spawnedBeam.selfId
                    local spawnReflectData = userdata_table(spawnedBeam, "mods.ai.reflectivePlating")
                    spawnReflectData.reflectionSpawn = true
                    spawnReflectData.reflect = false -- Reflected beams can't be reflected again
                end
            end
        
            -- Update reflection drawing data
            reflectData.x = location.x
            reflectData.y = location.y
            reflectData.angle = reflectData.angle + time_increment()*reflectData.angleSign*20 -- 20 degrees per second
            reflectData.thickness = 6*math.max(1, damage.iDamage)
            transfer_damage(reflectData.damage, damage)
            
            -- Negate damage
            damage.iDamage = 0
            damage.fireChance = 0
            damage.breachChance = 0
            damage.stunChance = 0
            damage.iIonDamage = 0
            damage.iSystemDamage = 0
            damage.iPersDamage = 0
            damage.iStun = 0
            damage.bLockdown = false
        end
    end)
end
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if not check_paused() then
        -- Check all projectiles that were spawned by a reflected beam
        for projectile in vter(Hyperspace.App.world.space.projectiles) do
            local reflectData = userdata_table(projectile, "mods.ai.reflectivePlating")
            if reflectData.reflectionSpawn then
                -- Check for the beam that spawned the reflection
                local spawner
                local spawnerReflectData
                for spawnerProjectile in vter(Hyperspace.App.world.space.projectiles) do
                    spawnerReflectData = userdata_table(spawnerProjectile, "mods.ai.reflectivePlating")
                    if spawnerReflectData.spawnId and spawnerReflectData.spawnId == projectile.selfId then
                        spawner = spawnerProjectile
                        break
                    end
                end
                if spawner and beam_pierces_shield(spawner) then 
                    -- Keep reflection damage up to date with source damage
                    transfer_damage(projectile.damage, spawnerReflectData.damage)
                    if spawnerReflectData.sp then projectile.damage.iShieldPiercing = spawnerReflectData.sp end
                else
                    -- Kill if the beam that spawned the projectile doesn't exist
                    -- or if the spawning beam is no longer hitting the ship
                    projectile:Kill()
                end
            end
        end
    end
end)
script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function() end, function(ship)
    for projectile in vter(Hyperspace.App.world.space.projectiles) do
        if projectile.targetId == ship.iShipId then
            local reflectData = userdata_table(projectile, "mods.ai.reflectivePlating")
            if reflectData.reflect and reflectData.x and reflectData.y and beam_pierces_shield(projectile) then
                -- Draw reflection if shields are not blocking the source
                Graphics.CSurface.GL_PushMatrix()
                Graphics.CSurface.GL_Translate(reflectData.x, reflectData.y)
                Graphics.CSurface.GL_Rotate(reflectData.angle, 0, 0)
                Graphics.CSurface.GL_DrawLaser(0, 0, 1280, reflectData.thickness, Graphics.GL_Color(projectile.color.r/255, projectile.color.g/255, projectile.color.b/255, 1))
                Graphics.CSurface.GL_PopMatrix()
            end
        end
    end
end)
