-- XML parsing imports
local string_replace = mods.multiverse.string_replace
local weaponTagParsers = mods.multiverse.weaponTagParsers

-- [Ion Busters - Multiply damage to ionized rooms, then deionize that room. Currently only works for beams.]

-- Add tagged weapons to table of ion busters
local ionBustWeapons = {}
table.insert(weaponTagParsers, function(weaponNode)
    local ionBustNode = weaponNode:first_node("uc-ionBust")
    if ionBustNode then
        ionBustWeapons[weaponNode:first_attribute("name"):value()] = ionBustNode:value()
    end
end)

-- Ion busting logic
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, newTile, beamHit)
    if ionBustWeapons[projectile.extend.name] then -- If the weapon has an ion bust value
        local roomId = shipManager.ship:GetSelectedRoomId(location.x, location.y, true) -- Get the selected room from the location that the beam is hitting
        local system = shipManager:GetSystemInRoom(roomId)
        if system and system.iLockCount > 0 then -- If the system is ionized

            system:LockSystem(0) -- Deionize the system
            damage.iDamage = damage.iDamage * ionBustWeapons[projectile.extend.name] -- Multiply the damage of the weapon by its damage multiplier

            Hyperspace.Sounds:PlaySoundMix(("beamShock"..math.random(1, 4)), -1, false)
        end
    end
    return Defines.Chain.CONTINUE, beamHit
end)

-- Add info to stats
script.on_internal_event(Defines.InternalEvents.WEAPON_STATBOX, function(bp, stats)
    if ionBustWeapons[bp.name] then
        return Defines.Chain.CONTINUE, stats.."\n\n"..string_replace(Hyperspace.Text:GetText("rvs_stat_ion_bust"), "\\1", ionBustWeapons[bp.name])
    -- Muffle VSCode warning
    ---@diagnostic disable-next-line: missing-return
    end
end)