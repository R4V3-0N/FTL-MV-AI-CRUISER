local get_room_at_location = mods.multiverse.get_room_at_location
local get_adjacent_rooms = mods.multiverse.get_adjacent_rooms

-- Make EMP pop extra shields
local popWeapons = {}
popWeapons.RVS_EMP_1 = {count = 2, countSuper = 2}
popWeapons.RVS_EMP_2 = {count = 2, countSuper = 2}
popWeapons.RVS_EMP_HEAVY_1 = {count = 4, countSuper = 6}
popWeapons.RVS_DRONE_EMP_LIGHT = {count = 1, countSuper = 1}
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
    local shieldPower = shipManager.shieldSystem.shields.power
    local popData = popWeapons[projectile and projectile.extend and projectile.extend.name]
    if popData then
        if shieldPower.super.first > 0 then
            if popData.countSuper > 0 then
                shipManager.shieldSystem:CollisionReal(projectile.position.x, projectile.position.y, Hyperspace.Damage(), true)
                shieldPower.super.first = math.max(0, shieldPower.super.first - popData.countSuper)
            end
        else
            shipManager.shieldSystem:CollisionReal(projectile.position.x, projectile.position.y, Hyperspace.Damage(), true)
            shieldPower.first = math.max(0, shieldPower.first - popData.count)
        end
    end
end)

-- Make EMP do ion damage
local roomDamageWeapons = {}
roomDamageWeapons.RVS_EMP_1 = Hyperspace.Damage()
roomDamageWeapons.RVS_EMP_1.iIonDamage = 2
roomDamageWeapons.RVS_EMP_2 = roomDamageWeapons.RVS_EMP_1
roomDamageWeapons.RVS_EMP_HEAVY_1 = Hyperspace.Damage()
roomDamageWeapons.RVS_EMP_HEAVY_1.iIonDamage = 3
roomDamageWeapons.RVS_DRONE_EMP_LIGHT = Hyperspace.Damage()
roomDamageWeapons.RVS_DRONE_EMP_LIGHT.iIonDamage = 1
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(ship, projectile, damage, response)
    local roomDamage = roomDamageWeapons[projectile and projectile.extend and projectile.extend.name]
    if roomDamage then
       local weaponName = projectile.extend.name
       projectile.extend.name = ""
       ship:DamageArea(projectile.position, roomDamage, true)
       projectile.extend.name = weaponName
    end
end)

local emptyRoomDamage = {
    RVS_EMP_1 = 1,
    RVS_EMP_2 = 1,
    RVS_EMP_HEAVY_1 = 2
}
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(ShipManager, projectile, Location, Damage, forceHit, shipFriendlyFire)
    local damageToDeal = emptyRoomDamage[projectile and projectile.extend and projectile.extend.name]
    if damageToDeal then
        local roomID = ShipManager.ship:GetSelectedRoomId(Location.x, Location.y, true)
        local system = ShipManager:GetSystemInRoom(roomID)
        if damageToDeal and not system then
            Damage.iDamage = Damage.iDamage + damageToDeal
        end
    end
    return Defines.CHAIN_CONTINUE, forceHit, shipFriendlyFire
end)

-- Give heavy EMP AOE damage
local aoeWeapons = {}
aoeWeapons.RVS_EMP_HEAVY_1 = Hyperspace.Damage()
aoeWeapons.RVS_EMP_HEAVY_1.iIonDamage = 1

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    local aoeDamage = aoeWeapons[projectile and projectile.extend and projectile.extend.name] --Indexing with nil (no projectile) will return nil, otherwise returns projectile name index
    if aoeDamage then
        local weaponName = projectile.extend.name
        projectile.extend.name = ""
        for roomId, _ in pairs(get_adjacent_rooms(shipManager.iShipId, get_room_at_location(shipManager, location, false), false)) do
            shipManager:DamageArea(shipManager:GetRoomCenter(roomId), aoeDamage, true)
        end
        projectile.extend.name = weaponName
    end
end)
