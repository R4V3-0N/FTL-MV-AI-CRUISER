-- Increase manning bonuses by 50% for sentient combat AI
script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR, function(ship, value)
    if ship and ship:HasEquipment("RVS_SENTIENT_COMBAT_AI") > 0 then
        local pilotSystem = ship:GetSystem(6)
        if pilotSystem and pilotSystem.iActiveManned > 0 then
            value = value + 1 + pilotSystem.iActiveManned
        end
        local engineSystem = ship:GetSystem(1)
        if engineSystem and engineSystem.iActiveManned > 0 then
            value = value + 1 + engineSystem.iActiveManned
        end
    end
    return Defines.Chain.CONTINUE, math.min(100, value)
end)
script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, function(ship, augment, value)
    if ship and ship:HasEquipment("RVS_SENTIENT_COMBAT_AI") > 0 then
        if augment == "SHIELD_RECHARGE" then
            local shieldSystem = ship:GetSystem(0)
            if shieldSystem and shieldSystem.iActiveManned > 0 then
                value = value + 0.05*shieldSystem.iActiveManned
            end
        elseif augment == "AUTO_COOLDOWN" then
            local weaponSystem = ship:GetSystem(3)
            if weaponSystem and weaponSystem.iActiveManned > 0 then
                value = value + 0.05*weaponSystem.iActiveManned
            end
        elseif augment == "FTL_BOOSTER" then
            local pilotSystem = ship:GetSystem(6)
            if pilotSystem and pilotSystem.iActiveManned > 0 then
                value = value + 0.01 + 0.01*pilotSystem.iActiveManned
            end
            local engineSystem = ship:GetSystem(1)
            if engineSystem and engineSystem.iActiveManned > 0 then
                value = value + 0.01 + 0.01*engineSystem.iActiveManned
            end
        end
    end
    return Defines.Chain.CONTINUE, value
end)
