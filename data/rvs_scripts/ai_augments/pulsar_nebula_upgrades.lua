--Power Upgrade
script.on_internal_event(Defines.InternalEvents.SET_BONUS_POWER, function(system, amount)
    if system:GetId() == Hyperspace.playerVariables.loc_ai_bonus_power_system then
        amount = amount + Hyperspace.ships(system._shipObj.iShipId):GetAugmentationValue("RVS_SCIENCE_ION_POWER")
    end
    return Defines.Chain.CONTINUE, amount
end)

--Evasion Armor
script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR,
function(ShipManager, dodge)
    dodge = dodge + ShipManager:GetAugmentationValue("RVS_SCIENCE_ION_DODGE")
    return Defines.Chain.CONTINUE, dodge
end)
