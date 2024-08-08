local userdata_table = mods.multiverse.userdata_table
local time_increment = mods.multiverse.time_increment

-- Anti Gravity Engines
script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR, function(shipManager, value)
    if shipManager:HasAugmentation("RVS_ANTI_GRAVITY_ENGINE") > 0 then
        local dodgeTable = userdata_table(shipManager, "mods.ai.grav_engine")
        local valueAdd = 0
        if dodgeTable.addDodge then
            valueAdd = math.ceil(dodgeTable.addDodge, 0)
        end
        value = math.max(value - 5 + valueAdd, 0)
    end
    return Defines.Chain.CONTINUE, value
end)

script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
    if shipManager:HasAugmentation("RVS_ANTI_GRAVITY_ENGINE") > 0 then
        if response.damage > 0 or response.superDamage > 0 then
            local dodgeTable = userdata_table(shipManager, "mods.ai.grav_engine")
            if dodgeTable.addDodge then
                dodgeTable.addDodge = math.min(dodgeTable.addDodge + 5, 40)
            else
                dodgeTable.addDodge = 5
            end
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("RVS_ANTI_GRAVITY_ENGINE") > 0 then
        local dodgeTable = userdata_table(shipManager, "mods.ai.grav_engine")
        if dodgeTable.addDodge then
            dodgeTable.addDodge = math.max(dodgeTable.addDodge - time_increment(), 0)
            if dodgeTable.addDodge == 0 then
                dodgeTable.addDodge = nil
            end
        end
    end
end)
