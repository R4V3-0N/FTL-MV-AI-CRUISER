-- Make ion busters do more damage to ionized rooms
local ionBustBeams = {
    RVS_BEAM_ION_BUST_1 = 2, --WEAPON_NAME will de-ionize rooms, and do 2 times as much damage to ionized rooms
    RVS_BEAM_ION_BUST_2 = 2,
    RVS_ARTILLERY_BEAM_ION_BUST = 2,
}
local RandomList = {
    New = function(self, table)
        table = table or {}
        self.__index = self
        setmetatable(table, self)
        return table
    end,

    GetItem = function(self)
        local index = Hyperspace.random32() % #self + 1
        return self[index]
    end,
}

local ionSounds = RandomList:New {"beamShock1", "beamShock2", "beamShock3", "beamShock4"}

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, 
function(ShipManager, Projectile, Location, Damage, newTile, beamHit)
    local weaponName = Projectile.extend.name --Get the name of the weapon firing the beam.
    local damageMultiplier = ionBustBeams[weaponName] --If the weapon has a multiplier, assign that to damageMultiplier. Otherwise, damageMultiplier will be nil
    if damageMultiplier then --If the weapon has a multiplier, then do the following
        local roomId = ShipManager.ship:GetSelectedRoomId(Location.x, Location.y, true) --Get the selected room from the location that the beam is hitting
        local system = ShipManager:GetSystemInRoom(roomId)
        if system and system.iLockCount > 0 then --If the system is ionized
            system:LockSystem(0) --Deionize the system
            Damage.iDamage = Damage.iDamage * damageMultiplier --Multiply the damage of the weapon by damageMultiplier
            local soundName = ionSounds:GetItem()
            Hyperspace.Sounds:PlaySoundMix(soundName, -1, false)
        end
    end 
    return Defines.Chain.CONTINUE, beamHit 
end)
