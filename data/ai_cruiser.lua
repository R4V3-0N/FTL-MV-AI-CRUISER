if not mods or not mods.vertexutil then
    error("Couldn't find Vertex Tags and Utility Functions! Make sure it's above mods which depend on it in the Slipstream load order", 2)
end
if not mods or not mods.inferno then
    error("Couldn't find Inferno Core! Make sure it's above mods which depend on it in the Slipstream load order", 2)
end

local vter = mods.vertexutil.vter
local INT_MAX = 2147483647

-- Heal holograms on jump
local wasJumping = false
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local isJumping = false
    if pcall(function() isJumping = Hyperspace.ships.player.bJumping end) then
        if not isJumping and wasJumping then
            for crew in vter(Hyperspace.ships.player.vCrewList) do
                if crew:GetSpecies() == "rvs_ai_hologram" then
                    crew:DirectModifyHealth(100.0)
                end
            end
        end
        wasJumping = isJumping
    end
end)

-- Replace burst projectile with beam for shotgun pinpoints
local pinpointBlueprint = Hyperspace.Global.GetInstance():GetBlueprints():GetWeaponBlueprint("RVS_PROJECTILE_BEAM_FOCUS_1")
local burstsToBeams = {}
burstsToBeams["RVS_BEAM_SHOTGUN_2"] = pinpointBlueprint
script.on_fire_event(Defines.FireEvents.WEAPON_FIRE, function(ship, weapon, projectile)
    local beamReplacement = burstsToBeams[Hyperspace.Get_Projectile_Extend(projectile).name]
    if beamReplacement then
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        local beam = spaceManager:CreateBeam(
            beamReplacement, projectile.position, projectile.currentSpace, projectile.ownerId,
            projectile.target, Hyperspace.Pointf(projectile.target.x, projectile.target.y + 1),
            projectile.destinationSpace, 1, projectile.heading)
        beam.sub_start.x = 500*math.cos(projectile.entryAngle)
        beam.sub_start.y = 500*math.sin(projectile.entryAngle) 
        projectile:Kill()
        return true
    end
end, INT_MAX)

local empWeapons = {} -- CV: Use a list of EMP weapons instead of comparing to one string
empWeapons["RVS_EMP_1"] = {
    shieldPop = 2,
    shieldSuperPop = 2,
    ion = 2
}

-- Make EMP pop extra shields
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
    local shieldPower = shipManager.shieldSystem.shields.power
    local empData = nil
    if pcall(function() empData = empWeapons[Hyperspace.Get_Projectile_Extend(projectile).name] end) and empData then
        if shieldPower.super.first > 0 then
            if empData.shieldSuperPop > 0 then
                local popper = Hyperspace.Damage()
                popper.iDamage = empData.shieldSuperPop
                shipManager.shieldSystem:CollisionReal(projectile.position.x, projectile.position.y, popper, true)
            end
        else
            shipManager.shieldSystem:CollisionReal(projectile.position.x, projectile.position.y, Hyperspace.Damage(), true)
            shieldPower.first = math.max(0, shieldPower.first - empData.shieldPop)
        end
    end
end)

-- Make EMP do ion damage
-- This is fixed with a method provided by Vert, I still have yet to understand the logic of this. But their notes are here to provide me closure when I am wise enough to comprehend it. I have retroactively applied comments from them with a prefix
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(ship, projectile, damage, response)
    local empData = nil
    if pcall(function() empData = empWeapons[Hyperspace.Get_Projectile_Extend(projectile).name] end) and empData then
       local empHullHit = Hyperspace.Damage()
       empHullHit.iIonDamage = empData.ion
       Hyperspace.Get_Projectile_Extend(projectile).name = "" --Vert: if the name of the active projectile is blank, the first line will evaluate to false and empHullImpact won't do anything within the next call of DamageArea
       ship:DamageArea(projectile.position, empHullHit, true) --Vert: Can now call DamageArea safely
       Hyperspace.Get_Projectile_Extend(projectile).name = "RVS_EMP_1" --Vert: set the name back for any future functions to use
    end
end)

--[[ Old shield popping code
--checks on internal event, that event is defined as a shield collission, which when it detects a shield collission it then calls for empShieldImpact
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(ship, projectile, damage, response) --this functions arguement is looking at a bunch of things that I have yet to comprehend but it should cover all the basics I need for when the projectile hits a shield
    if Hyperspace.Get_Projectile_Extend(projectile).name == "RVS_EMP_1" then            --this gives me an output that tells me which projectile hit a shield which it then compares to the blueprint of the weapon, if it equals rvs_emp_1 then it continues. If not it stops
		local pop = Hyperspace.Damage()	--we've assigned the object Hyperspace.Damage as pop, which we made local to avoid any conflicts with other mods.
		pop.iDamage = 2
		ship.shieldSystem:CollisionReal(projectile.position.x, projectile.position.y, pop, true)
        -- ship:CollisionShield(projectile.position, projectile.position, pop, false)
		log(response.collision_type)
    end
end)
]]--

--Funny beam
local ionBustBeams = {
    RVS_BEAM_ION_BUST_1 = 2, --WEAPON_NAME will de-ionize rooms, and do 2 times as much damage to ionized rooms
}


script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, 
function(ShipManager, Projectile, Location, Damage, newTile, beamHit)
  local weaponName = Hyperspace.Get_Projectile_Extend(Projectile).name --Get the name of the weapon firing the beam.
  local damageMultiplier = ionBustBeams[weaponName] --If the weapon has a multiplier, assign that to damageMultiplier. Otherwise, damageMultiplier will be nil
  if damageMultiplier then --If the weapon has a multiplier, then do the following
    local roomId = ShipManager.ship:GetSelectedRoomId(Location.x, Location.y, true) --Get the selected room from the location that the beam is hitting
    local system = ShipManager:GetSystemInRoom(roomId)
    if system.iLockCount > 0 then --If the system is ionized
        system:LockSystem(0) --Deionize the system
        Damage.iDamage = Damage.iDamage * damageMultiplier --Multiply the damage of the weapon by damageMultiplier
        local soundName = "ionHit" .. Hyperspace.random32() % 3 
        Hyperspace.Global.GetInstance():GetSoundControl():PlaySoundMix(soundName 1, true)
    end
  end 
  return Defines.Chain.CONTINUE, beamHit 
end)