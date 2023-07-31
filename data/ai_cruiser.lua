if not mods or not mods.vertexutil then
    error("Couldn't find Vertex Tags and Utility Functions! Make sure it's above mods which depend on it in the Slipstream load order")
end
if not mods or not mods.inferno then
    error("Couldn't find Inferno Core! Make sure it's above mods which depend on it in the Slipstream load order")
end

local vter = mods.vertexutil.vter
local userdata_table = mods.vertexutil.userdata_table
local get_room_at_location = mods.vertexutil.get_room_at_location
local get_adjacent_rooms = mods.vertexutil.get_adjacent_rooms

local function bool_to_num(bool)
    if bool then return 1 end
    return 0
end

-- Track whether we're in a nebula or a nebula with an ion storm
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local space = Hyperspace.Global.GetInstance():GetCApp().world.space
    Hyperspace.playerVariables.loc_nebula_nostorm = bool_to_num(space.bNebula and not space.bStorm)
    Hyperspace.playerVariables.loc_nebula_storm = bool_to_num(space.bStorm)
end)

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
local pinpoint1 = Hyperspace.Global.GetInstance():GetBlueprints():GetWeaponBlueprint("RVS_PROJECTILE_BEAM_FOCUS_1")
local pinpoint2 = Hyperspace.Global.GetInstance():GetBlueprints():GetWeaponBlueprint("RVS_PROJECTILE_BEAM_FOCUS_2")
local burstsToBeams = {}
burstsToBeams["RVS_BEAM_SHOTGUN_1"] = pinpoint1
burstsToBeams["RVS_BEAM_SHOTGUN_2"] = pinpoint1
burstsToBeams["RVS_BEAM_SHOTGUN_3"] = pinpoint2
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local beamReplacement = burstsToBeams[weapon.blueprint.name]
    if beamReplacement then
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        local beam = spaceManager:CreateBeam(
            beamReplacement, projectile.position, projectile.currentSpace, projectile.ownerId,
            projectile.target, Hyperspace.Pointf(projectile.target.x, projectile.target.y + 1),
            projectile.destinationSpace, 1, projectile.heading)
        beam.sub_start.x = 500*math.cos(projectile.entryAngle)
        beam.sub_start.y = 500*math.sin(projectile.entryAngle) 
        projectile:Kill()
    end
end)

-- Make EMP pop extra shields
local popWeapons = mods.inferno.popWeapons
popWeapons.RVS_EMP_1 = {count = 2, countSuper = 2}
popWeapons.RVS_EMP_2 = {count = 2, countSuper = 2}
popWeapons.RVS_EMP_HEAVY_1 = {count = 4, countSuper = 6}
popWeapons.RVS_DRONE_EMP_LIGHT = {count = 1, countSuper = 1}

-- Make EMP do ion damage
local roomDamageWeapons = mods.inferno.roomDamageWeapons
roomDamageWeapons.RVS_EMP_1 = {ion = 2}
roomDamageWeapons.RVS_EMP_2 = {ion = 2}
roomDamageWeapons.RVS_EMP_HEAVY_1 = {ion = 3}
roomDamageWeapons.RVS_DRONE_EMP_LIGHT = {ion = 1}

local emptyRoomDamage = {
    RVS_EMP_1 = 1,
    RVS_EMP_2 = 1,
    RVS_EMP_HEAVY_1 = 2
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

local aoeWeapons = {}
aoeWeapons["RVS_EMP_HEAVY_1"] = Hyperspace.Damage()
aoeWeapons["RVS_EMP_HEAVY_1"].iIonDamage = 1

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    local weaponName = nil
    pcall(function() weaponName = Hyperspace.Get_Projectile_Extend(projectile).name end)
    local aoeDamage = aoeWeapons[weaponName]
    if aoeDamage then
        Hyperspace.Get_Projectile_Extend(projectile).name = ""
        for roomId, _ in pairs(get_adjacent_rooms(shipManager.iShipId, get_room_at_location(shipManager, location, false), false)) do
            shipManager:DamageArea(shipManager:GetRoomCenter(roomId), aoeDamage, true)
        end
        Hyperspace.Get_Projectile_Extend(projectile).name = weaponName
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

-- Make a drone target enemy drones first before normal anti ship targetting
-- CV: I wrote this while I felt like crap and my brain was working at 0.1% capacity, god help whoever has to read it later
local function set_drone_destination(drone)
    local target = userdata_table(drone, "mods.ai.droneTarget").target
    if target then
        local shieldCenter = Hyperspace.Global.GetInstance():GetShipManager(drone.currentSpace).ship:GetBaseEllipse().center
        drone.destinationLocation.x = (target.currentLocation.x - shieldCenter.x)*1.15 + shieldCenter.x
        drone.destinationLocation.y = (target.currentLocation.y - shieldCenter.y)*1.15 + shieldCenter.y
    end
end
local function aquire_drone_target(ship, droneName)
    local otherShip = Hyperspace.Global.GetInstance():GetShipManager(1 - ship.iShipId)
    if otherShip then
        local target = nil
        for drone in vter(otherShip.spaceDrones) do
            if drone.deployed and drone.currentSpace == otherShip.iShipId and not drone.explosion.tracker.running and (drone.blueprint.typeName == "DEFENSE" or drone.blueprint.typeName == "SHIELD") then
                target = drone
                break
            end
        end
        for drone in vter(ship.spaceDrones) do
            if drone.blueprint.name == droneName then
                local targetTable = userdata_table(drone, "mods.ai.droneTarget")
                targetTable.target = target
                if target then
                    drone.targetLocation.x = target.currentLocation.x
                    drone.targetLocation.y = target.currentLocation.y
                    targetTable.targetingDrone = true
                elseif targetTable.targetingDrone then
                    drone.targetLocation = otherShip:GetRandomRoomCenter()
                    targetTable.targetingDrone = false
                end
                if drone.powered and not targetTable.poweredLastFrame then
                    set_drone_destination(drone)
                end
                targetTable.poweredLastFrame = drone.powered
            end
        end
    end
end
script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
    if drone.blueprint.name == "RVS_AI_MICROFIGHTER_INTERCEPTER" then
        set_drone_destination(drone)
    end
end)
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if Hyperspace.ships.player then aquire_drone_target(Hyperspace.ships.player, "RVS_AI_MICROFIGHTER_INTERCEPTER") end
    if Hyperspace.ships.enemy then aquire_drone_target(Hyperspace.ships.enemy, "RVS_AI_MICROFIGHTER_INTERCEPTER") end
end)

--Make a drone target systems only
local function retarget_drone_to_system(ship, droneName)
    local otherShip = Hyperspace.Global.GetInstance():GetShipManager(1 - ship.iShipId)
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
--Number of shots a drone may fire before it is destroyed
local limitShots = {}
limitShots.RVS_AI_MISSILE_1 = 3

--Implementation uses lifespan for save and load, replace with table implementation when saving features are available
--I think lifespan is only used for surge drones so it's ok to use here
script.on_internal_event(Defines.InternalEvents.DRONE_FIRE,
function(Projectile, Drone)
    local shots = limitShots[Drone.blueprint.name]
    --Lifespan incremented by base game code
    if shots then
        if Drone.lifespan == 2147483647 then
            Drone.lifespan = shots - 1
        elseif Drone.lifespan == 0 then
            Drone:BlowUp(false)
            Drone.lifespan = shots
        end
    end
    return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.DRONE_FIRE,
function(Projectile, Drone)
    if Drone.blueprint.name == "RVS_BEAM_DEFENSE_1" then
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        --Spawn beam from drone to target
        spaceManager:CreateBeam(
            Hyperspace.Global.GetInstance():GetBlueprints():GetWeaponBlueprint("RVS_BEAM_DEFENSE_1"), 
            Drone.currentLocation, 
            Projectile.currentSpace,
            1 - Projectile.ownerId,
            Projectile.target, 
            Hyperspace.Pointf(Projectile.target.x, Projectile.target.y + 1),
            Projectile.currentSpace, 
            1, 
            -1)
        --Destroy target (Beam is not programmed to do so in base game)
        for target in vter(spaceManager.projectiles) do
            if target:GetSelfId() == Drone.currentTargetId then
                target.death_animation:Start(true)
                break
            end
        end
        
        return Defines.Chain.PREEMPT
    end
    return Defines.Chain.CONTINUE
end)

local function LoadEvent(eventName)
    local world = Hyperspace.Global.GetInstance():GetCApp().world
    Hyperspace.CustomEventsParser.GetInstance():LoadEvent(world, eventName, false, -1)
end

local SWARM_KEY = {}
local shotsToSpawn = 2 --Spawn a drone every shotsToSpawn shots
script.on_internal_event(Defines.InternalEvents.DRONE_FIRE,
function(Projectile, Drone)
    if Drone.blueprint.name == "RVS_AI_MICROFIGHTER_SWARM" then
        if not Drone.table[SWARM_KEY] then
            Drone.table[SWARM_KEY] = shotsToSpawn
        end

        Drone.table[SWARM_KEY] = Drone.table[SWARM_KEY] - 1

        if Drone.table[SWARM_KEY] <= 0 then
            Drone.table[SWARM_KEY] = shotsToSpawn

            local surgeEvent = Drone.iShipId == 0 and "RVS_AI_SWARM_DRONE_SURGE_PLAYER" or "RVS_AI_SWARM_DRONE_SURGE_ENEMY"
            LoadEvent(surgeEvent)
            local superDrones = Hyperspace.Global.GetInstance():GetShipManager(Drone.iShipId).superDrones
            --Each drone only fires 4 shots
            superDrones[0].lifespan = 4
            --So new drones don't overwrite old drones, equivalant to <clearSuperDrones>
            superDrones:clear()
        end
    end
    return Defines.Chain.CONTINUE
end)
