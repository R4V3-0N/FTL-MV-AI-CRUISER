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

-- Make EMP pop extra shields
local popWeapons = mods.inferno.popWeapons
popWeapons.RVS_EMP_1 = {count = 2, countSuper = 2}
popWeapons.RVS_DRONE_EMP_LIGHT = {count = 1, countSuper = 1}
-- Make EMP do ion damage
local roomDamageWeapons = mods.inferno.roomDamageWeapons
roomDamageWeapons.RVS_EMP_1 = {ion = 2}
roomDamageWeapons.RVS_DRONE_EMP_LIGHT = {ion = 1}

local emptyRoomDamage = {
    RVS_EMP_1 = 1
}
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(ShipManager, Projectile, Location, Damage, forceHit, shipFriendlyFire)
    local roomID = ShipManager.ship:GetSelectedRoomId(Location.x, Location.y, true)
    local system = ShipManager:GetSystemInRoom(roomID)
    if not system then
        local emptyRoomDamage = emptyRoomDamage[Hyperspace.Get_Projectile_Extend(Projectile).name] or 0
        Damage.iDamage = Damage.iDamage + emptyRoomDamage
    end
    return Defines.CHAIN_CONTINUE, forceHit, shipFriendlyFire
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

ionSounds = RandomList:New {"beamShock1", "beamShock2", "beamShock3", "beamShock4"}

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, 
function(ShipManager, Projectile, Location, Damage, newTile, beamHit)
  local weaponName = Hyperspace.Get_Projectile_Extend(Projectile).name --Get the name of the weapon firing the beam.
  local damageMultiplier = ionBustBeams[weaponName] --If the weapon has a multiplier, assign that to damageMultiplier. Otherwise, damageMultiplier will be nil
  if damageMultiplier then --If the weapon has a multiplier, then do the following
    local roomId = ShipManager.ship:GetSelectedRoomId(Location.x, Location.y, true) --Get the selected room from the location that the beam is hitting
    local system = ShipManager:GetSystemInRoom(roomId)
    if system and system.iLockCount > 0 then --If the system is ionized
        system:LockSystem(0) --Deionize the system
        Damage.iDamage = Damage.iDamage * damageMultiplier --Multiply the damage of the weapon by damageMultiplier
        local soundName = ionSounds:GetItem()
        Hyperspace.Global.GetInstance():GetSoundControl():PlaySoundMix(soundName, -1, true)
    end
  end 
  return Defines.Chain.CONTINUE, beamHit 
end)

--Make a drone target enemy drones first before normal anti ship targetting
local function retarget_drone_to_ddrone(ship, droneName)
    local otherShip = Hyperspace.Global.GetInstance():GetShipManager((ship.iShipId + 1)%2)
    if otherShip then
        local target = nil
        for drone in vter(otherShip.spaceDrones) do
            if drone.deployed and drone.blueprint.typeName == "DEFENSE" then
                target = drone
                break
            end
        end
        if target then
            for drone in vter(ship.spaceDrones) do
                if drone.blueprint.name == droneName then
                    drone.targetLocation.x = target.currentLocation.x
                    drone.targetLocation.y = target.currentLocation.y
                end
            end
        end
    end
end
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if Hyperspace.ships.player then retarget_drone_to_ddrone(Hyperspace.ships.player, "RVS_AI_MICROFIGHTER_INTERCEPTER") end
    if Hyperspace.ships.enemy then retarget_drone_to_ddrone(Hyperspace.ships.enemy, "RVS_AI_MICROFIGHTER_INTERCEPTER") end
end)

--Make a drone target systems only
local function retarget_drone_to_system(ship, droneName)
    local otherShip = Hyperspace.Global.GetInstance():GetShipManager((ship.iShipId + 1)%2)
    if otherShip then
        local otherShipGraph = Hyperspace.ShipGraph.GetShipInfo(otherShip.iShipId)
        for drone in vter(ship.spaceDrones) do
            if drone.blueprint.name == droneName then
                local targetRoom = otherShipGraph:GetSelectedRoom(drone.targetLocation.x, drone.targetLocation.y, true)
                if not otherShip:GetSystemInRoom(targetRoom) then
                    targetRoom = otherShip.vSystemList[Hyperspace.random32()%otherShip.vSystemList:size()].roomId
                    local targetRoomShape = otherShipGraph:GetRoomShape(targetRoom)
                    drone.targetLocation.x = targetRoomShape.x + targetRoomShape.w/2
                    drone.targetLocation.y = targetRoomShape.y + targetRoomShape.h/2
                end
            end
        end
    end
end
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if Hyperspace.ships.player then retarget_drone_to_system(Hyperspace.ships.player, "RVS_AI_MICROFIGHTER_SHOCK") end
    if Hyperspace.ships.enemy then retarget_drone_to_system(Hyperspace.ships.enemy, "RVS_AI_MICROFIGHTER_SHOCK") end
end)


--Harpoon thingy
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT,
function(ShipManager, Projectile, Location, Damage, shipFriendlyFire)
  if Hyperspace.Get_Projectile_Extend(Projectile).name == "HARPOON_THINGY" then
    local destinationRoomNumber = ShipManager.ship:GetSelectedRoomId(Location.x, Location.y, true)
    local firingShip = Hyperspace.Global.GetInstance():GetShipManager(Projectile.ownerId)
    local airlockRooms = {}
    for door in vter(firingShip.ship.vOuterAirlocks) do
        airlockRooms[door.iRoom1] = true
    end
    local playTeleportSound = false
    for crew in vter(firingShip.vCrewList) do
      if crew.iShipId == firingShip.iShipId and airlockRooms[crew.iRoomId] then --only sends player crew
        Hyperspace.Get_CrewMember_Extend(crew):InitiateTeleport(ShipManager.iShipId, destinationRoomNumber)
        playTeleportSound = true
      end
    end
  
    if playTeleportSound then
      Hyperspace.Global.GetInstance():GetSoundControl():PlaySoundMix("teleport", -1, false)
    end
  end
  return Defines.CHAIN_CONTINUE
end)