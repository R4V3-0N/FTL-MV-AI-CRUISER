local make_set = mods.rvsai.make_set

-- Give plasma projectiles a chance to do damage to rooms on fire
local plasmaProjectiles = make_set{
    "RVS_SHOT_PLASMA_NORMAL",
    "RVS_SHOT_PLASMA_CRIT",
    "RVS_DRONE_PLASMA_THROWER",
    "RVS_SHOT_PLASMA_PLUS_NORMAL",
    "RVS_SHOT_PLASMA_PLUS_CRIT",
    "RVS_SHOT_PLASMA_HS_NORMAL",
    "RVS_SHOT_PLASMA_HS_CRIT",
}
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, 
function(ShipManager, Projectile, Location, Damage, forceHit, shipFriendlyFire)
    local isPlasma = plasmaProjectiles[Projectile and Projectile.extend.name] --Indexing with nil (no projectile) will return nil, otherwise returns Projectile name index
    if isPlasma then
        local roomId = ShipManager.ship:GetSelectedRoomId(Location.x, Location.y, true)
        if roomId >= 0 then
            local roomShape = ShipManager.ship.vRoomList[roomId].rect
            local w = roomShape.w / 35
            local h = roomShape.h / 35
        
            local tileCount = w * h
            local fireCount = ShipManager:GetFireCount(roomId)

            local firePercent = (fireCount / tileCount) * 100
            local hullDamageChance = firePercent / 3 -- 33% chance to damage  room that's fully on fire

            if math.random(100) <= hullDamageChance then
                Damage.iDamage = Damage.iDamage + 1
            end
        end
    end
    return Defines.CHAIN_CONTINUE, forceHit, shipFriendlyFire
end)
