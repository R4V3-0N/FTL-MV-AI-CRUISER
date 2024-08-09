local vter = mods.multiverse.vter
local string_starts = mods.multiverse.string_starts

-- Small buff/debuff applied on evasion while projector is active, only for the player
script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR,  function(ship, value)
    local playerShip = Hyperspace.ships.player
    if not playerShip or not playerShip.weaponSystem then return end
    for weapon in vter(playerShip.weaponSystem.weapons) do
        if string_starts(weapon.blueprint.name, "RVS_PROJECTOR_AVATAR") and weapon.powered then
            value = value + (ship.iShipId == 0 and 5 or -5)
        end
    end
    return Defines.Chain.CONTINUE, value
end)

-- Half pre-ignited on jump (only normal version 'cause chaos is fully pre-ignited)
script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(ship)
    if not ship.weaponSystem then return end
    for weapon in vter(ship.weaponSystem.weapons) do
        if weapon.blueprint.name == "RVS_PROJECTOR_AVATAR" and weapon.powered then
            weapon.cooldown.first = weapon.cooldown.second/2
        end
    end
end)
