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
    return bool and 1 or 0
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
burstsToBeams.RVS_BEAM_SHOTGUN_1 = pinpoint1
burstsToBeams.RVS_BEAM_SHOTGUN_2 = pinpoint1
burstsToBeams.RVS_BEAM_SHOTGUN_3 = pinpoint2
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
        local emptyRoomDamage = emptyRoomDamage[Projectile.extend.name] or 0
        Damage.iDamage = Damage.iDamage + emptyRoomDamage
    end
    return Defines.CHAIN_CONTINUE, forceHit, shipFriendlyFire
end)

-- Give heavy EMP AOE damage
local aoeWeapons = {}
aoeWeapons.RVS_EMP_HEAVY_1 = Hyperspace.Damage()
aoeWeapons.RVS_EMP_HEAVY_1.iIonDamage = 1

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    local weaponName = nil
    pcall(function() weaponName = projectile.extend.name end)
    local aoeDamage = aoeWeapons[weaponName]
    if aoeDamage then
        projectile.extend.name = ""
        for roomId, _ in pairs(get_adjacent_rooms(shipManager.iShipId, get_room_at_location(shipManager, location, false), false)) do
            shipManager:DamageArea(shipManager:GetRoomCenter(roomId), aoeDamage, true)
        end
        projectile.extend.name = weaponName
    end
end)

-- Make enemy effectors target only systems
local systemTargetWeapons = {}
local sysWeights = {}
sysWeights.weapons = 6
sysWeights.shields = 6
sysWeights.pilot = 3
sysWeights.engines = 3
sysWeights.teleporter = 2
sysWeights.hacking = 2
sysWeights.medbay = 2
sysWeights.clonebay = 2
systemTargetWeapons.RA_EFFECTOR_1 = sysWeights
systemTargetWeapons.RA_EFFECTOR_2 = sysWeights
systemTargetWeapons.RA_EFFECTOR_HEAVY = sysWeights
systemTargetWeapons.RA_EFFECTOR_CHAIN = sysWeights

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local playerShip = Hyperspace.ships.player
    local sysWeights = nil
    if weapon.iShipId == 1 and playerShip and pcall(function() sysWeights = systemTargetWeapons[weapon.blueprint.name] end) and sysWeights then
        local sysTargets = {}
        local weightSum = 0
        
        -- Collect all player systems and their weights
        for system in vter(playerShip.vSystemList) do
            local sysId = system:GetId()
            if playerShip:HasSystem(sysId) then
                local weight = sysWeights[Hyperspace.ShipSystem.SystemIdToName(sysId)] or 1
                weightSum = weightSum + weight
                table.insert(sysTargets, {
                    id = sysId,
                    weight = weight
                })
            end
        end
        
        -- Pick a random system using the weights
        if #sysTargets > 0 then
            local rnd = math.random(weightSum);
            for i = 1, #sysTargets do
                if rnd <= sysTargets[i].weight then
                    projectile.target = playerShip:GetRoomCenter(playerShip:GetSystemRoom(sysTargets[i].id))
                    projectile:ComputeHeading()
                    return
                end
                rnd = rnd - sysTargets[i].weight
            end
            error("Weighted selection error - reached end of options without making a choice!")
        end
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
  local weaponName = Projectile.extend.name --Get the name of the weapon firing the beam.
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
  if Projectile.extend.name == "HARPOON_THINGY" then
    local destinationRoomNumber = ShipManager.ship:GetSelectedRoomId(Location.x, Location.y, true)
    local firingShip = Hyperspace.Global.GetInstance():GetShipManager(Projectile.ownerId)
    local airlockRooms = {}
    for door in vter(firingShip.ship.vOuterAirlocks) do
        airlockRooms[door.iRoom1] = true
    end
    local playTeleportSound = false
    for crew in vter(firingShip.vCrewList) do
      if crew.iShipId == firingShip.iShipId and airlockRooms[crew.iRoomId] then --only sends player crew
        crew.extend:InitiateTeleport(ShipManager.iShipId, destinationRoomNumber)
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

-- Spawn children for swarm drone
local shotsToSpawn = 2 -- Spawn a drone every shotsToSpawn shots
local function spawn_temp_drone(table)
    local name = table.name
    local ownerShip = table.ownerShip
    local targetShip = table.targetShip
    local targetLocation = table.targetLocation
    local shots = table.shots
    local position = table.position

    local drone = ownerShip:CreateSpaceDrone(Hyperspace.Global.GetInstance():GetBlueprints():GetDroneBlueprint(name))
    drone.powerRequired = 0
    drone:SetMovementTarget(targetShip._targetable)
    drone:SetWeaponTarget(targetShip._targetable)
    drone.lifespan = shots or 2
    drone.powered = true
    drone:SetDeployed(true)
    drone.bDead = false
    if position then drone:SetCurrentLocation(position) end
    if targetLocation then drone.targetLocation = targetLocation end
    return drone
end
script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
    if drone.blueprint.name == "RVS_AI_MICROFIGHTER_SWARM" then
        local swarmData = userdata_table(drone, "mods.ai.droneSwarm")
        swarmData.shots = (swarmData.shots or shotsToSpawn) - 1
        if swarmData.shots <= 0 then
            swarmData.shots = shotsToSpawn
            local thisShip = Hyperspace.Global.GetInstance():GetShipManager(drone.iShipId)
            local otherShip = Hyperspace.Global.GetInstance():GetShipManager(1 - drone.iShipId)
            local childDrone = spawn_temp_drone{name = "RVS_AI_MICROFIGHTER_SWARM_CHILD", ownerShip = thisShip, targetShip = otherShip}
            userdata_table(childDrone, "mods.ai.droneSwarm").clearOnJump = true
        end
    end
    return Defines.Chain.CONTINUE
end)
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship.bJumping then
        for drone in vter(ship.spaceDrones) do
            if userdata_table(drone, "mods.ai.droneSwarm").clearOnJump then
                drone:SetDestroyed(true, false)
            end
        end
    end
end)

--RVS_AI_SWARM implementation (CHANGE NAME LATER)

--Spawn drone when drone is destroyed
script.on_internal_event(Defines.InternalEvents.DRONE_COLLISION,
function(Drone, Projectile, Damage, CollisionResponse)
    local thisShip = Hyperspace.Global.GetInstance():GetShipManager(Drone.iShipId)
    if Damage.iIonDamage <= 0 and Damage.iDamage > 0 and thisShip:HasAugmentation("RVS_AI_SWARM") > 0 then --If drone would be destroyed and ship has drone spawning aug
        local otherShip = Hyperspace.Global.GetInstance():GetShipManager(1 - Drone.iShipId)
        --Spawn drone at drone's location, location shouldn't really matter if destroyed drone is a defense drone because it's in a different space anyway
        spawn_temp_drone{name = "RVS_AI_MICROFIGHTER_SWARM_CHILD", ownerShip = thisShip, targetShip = otherShip, position = Drone.currentLocation} 
    end
    return Defines.Chain.CONTINUE
end) 


--V: Should this trigger on resist? Leaving like this for now unless told otherwise.
local function drone_vengeance(ship, damage)
    local rolledVengeance = math.random(100) <= 15 --15% chance
    if damage.iDamage > 0 and ship:HasAugmentation("RVS_AI_SWARM") > 0 and rolledVengeance then
        local otherShip = Hyperspace.Global.GetInstance():GetShipManager(1 - ship.iShipId)
        spawn_temp_drone{name = "RVS_AI_MICROFIGHTER_SWARM_CHILD", ownerShip = ship, targetShip = otherShip}
    end
end
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, 
function(ship, projectile, location, damage, shipFriendlyFire)
    drone_vengeance(ship, damage)
    return Defines.Chain.CONTINUE
end, -1000) --Allow other functions to modify parameters first

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM,
function(ship, projectile, location, damage, newTile, beamHit)
    if beamHit == Defines.BeamHit.NEW_ROOM then
        drone_vengeance(ship, damage)   
    end
    return Defines.Chain.CONTINUE, beamHit
end, -1000) --Allow other functions to modify parameters first

--Flock gun implementation
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP,
function(ship)
    if ship.weaponSystem then
        local numDronesActive = 0
        for drone in vter(ship.spaceDrones) do
            if not drone.bDead and drone.powered then
                numDronesActive = numDronesActive + 1
            end
        end
        
        for weapon in vter(ship.weaponSystem.weapons) do
            if weapon.blueprint.name == "RVS_FLOCK_GUN" then
                weapon.radius = weapon.blueprint.radius - (5 * numDronesActive)
                weapon.radius = math.max(weapon.radius, 0)
            end
        end
    end
end)

local function RandomPointCircle(center, radius)
    local radius = radius * math.random()
    local angle = 2 * math.pi * math.random()
    local x = center.x + radius * math.cos(angle)
    local y = center.y + radius * math.sin(angle)
    return x, y
end

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE,
function(projectile, weapon)
    if weapon.blueprint.name == "RVS_FLOCK_GUN" then
        projectile.target.x, projectile.target.y = RandomPointCircle(weapon.lastTargets[0], weapon.radius)
        local ship = Hyperspace.Global.GetInstance():GetShipManager(weapon.iShipId)
        local numDronesActive = 0
        for drone in vter(ship.spaceDrones) do
            if not drone.bDead and drone.powered then
                numDronesActive = numDronesActive + 1
            end
        end
        --TODO: Add alternate projectile sprite and sound for crit shots
        if math.random(6) <= numDronesActive then
            projectile.damage.iDamage = projectile.damage.iDamage * 2
        end

    end
end)


--Effector Artillery Targetting
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE,
function(projectile, weapon)
    if weapon.blueprint.name == "" then

    end
end)