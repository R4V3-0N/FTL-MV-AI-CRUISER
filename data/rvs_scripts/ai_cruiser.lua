if not mods or not mods.vertexutil then
    error("Couldn't find Vertex Tags and Utility Functions! Make sure it's above mods which depend on it in the Slipstream load order")
end

local vter = mods.vertexutil.vter
local userdata_table = mods.vertexutil.userdata_table
local get_room_at_location = mods.vertexutil.get_room_at_location
local get_adjacent_rooms = mods.vertexutil.get_adjacent_rooms

local function bool_to_num(bool)
    return bool and 1 or 0
end

local function PopRandom(_table)
    return table.remove(_table, math.random(#_table))
end

local function get_crew_count_name(ship, speciesName)
    if ship then
        local count = 0
        if type(speciesName) == "string" then
            speciesName = {[speciesName] = true}
        end
        for crew in vter(ship.vCrewList) do
            if crew.iShipId == ship.iShipId and speciesName[crew:GetSpecies()] then
                count = count + 1
            end
        end
        local otherShip = Hyperspace.ships(1 - ship.iShipId)
        if otherShip then
            for crew in vter(otherShip.vCrewList) do
                if crew.iShipId == ship.iShipId and speciesName[crew:GetSpecies()] then
                    count = count + 1
                end
            end
        end
        return count
    end
    return 0
end

-- Make a list of hologram crew that's easier to reference
local holoSpecies = {}
script.on_load(function()
    for holoName in vter(Hyperspace.Blueprints:GetBlueprintList("RVS_LIST_CREW_AI_AVATAR")) do
        holoSpecies[holoName] = true
    end
end)

-- Track whether we're in a nebula or a nebula with an ion storm
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local space = Hyperspace.Global.GetInstance():GetCApp().world.space
    Hyperspace.playerVariables.loc_nebula_nostorm = bool_to_num(space.bNebula and not space.bStorm)
    Hyperspace.playerVariables.loc_nebula_storm = bool_to_num(space.bStorm)
end)

-- Track holo count
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local playerShip = Hyperspace.ships.player
    if playerShip then
        local vars = Hyperspace.playerVariables
        if playerShip:HasEquipment("RVS_REQ_HOLO_TRACK_DEATH") > 0 then
            local holoCount = get_crew_count_name(playerShip, holoSpecies)
            if vars.loc_holos_last_count > -1 and vars.loc_holos_last_count > holoCount then
                vars.loc_holos_dead = vars.loc_holos_dead + vars.loc_holos_last_count - holoCount
            end
            vars.loc_holos_last_count = holoCount
        else
            vars.loc_holos_last_count = -1
        end
    end
end)

-- Heal holograms on jump
local function holoHeal(ship)
    for crew in vter(ship.vCrewList) do
        if holoSpecies[crew:GetSpecies()] then
            crew:DirectModifyHealth(100.0)
        end
    end
end
script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, holoHeal)
script.on_internal_event(Defines.InternalEvents.ON_WAIT, holoHeal)

-- Increase manning bonuses by 50% for sentient combat AI
script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR, function(ship, value)
    if ship and ship:HasEquipment("RVS_SENTIENT_COMBAT_AI") > 0 then
        local pilotSystem = ship:GetSystem(6)
        if pilotSystem and pilotSystem.iActiveManned > 0 then
            value = value + 1 + pilotSystem.iActiveManned
        end
        local engineSystem = ship:GetSystem(1)
        if engineSystem and engineSystem.iActiveManned > 0 then
            value = value + 1 + engineSystem.iActiveManned
        end
    end
    return Defines.Chain.CONTINUE, math.min(100, value)
end)
script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, function(ship, augment, value)
    if ship and ship:HasEquipment("RVS_SENTIENT_COMBAT_AI") > 0 then
        if augment == "SHIELD_RECHARGE" then
            local shieldSystem = ship:GetSystem(0)
            if shieldSystem and shieldSystem.iActiveManned > 0 then
                value = value + 0.05*shieldSystem.iActiveManned
            end
        elseif augment == "AUTO_COOLDOWN" then
            local weaponSystem = ship:GetSystem(3)
            if weaponSystem and weaponSystem.iActiveManned > 0 then
                value = value + 0.05*weaponSystem.iActiveManned
            end
        elseif augment == "FTL_BOOSTER" then
            local pilotSystem = ship:GetSystem(6)
            if pilotSystem and pilotSystem.iActiveManned > 0 then
                value = value + 0.01 + 0.01*pilotSystem.iActiveManned
            end
            local engineSystem = ship:GetSystem(1)
            if engineSystem and engineSystem.iActiveManned > 0 then
                value = value + 0.01 + 0.01*engineSystem.iActiveManned
            end
        end
    end
    return Defines.Chain.CONTINUE, value
end)

-- Replace burst projectile with beam for shotgun pinpoints
local pinpoint1 = Hyperspace.Blueprints:GetWeaponBlueprint("RVS_PROJECTILE_BEAM_FOCUS_1")
local pinpoint2 = Hyperspace.Blueprints:GetWeaponBlueprint("RVS_PROJECTILE_BEAM_FOCUS_2")
local fm_epinpoint1 = Hyperspace.Blueprints:GetWeaponBlueprint("FM_RVS_PROJECTILE_BEAM_ENERGY_FOCUS_1")
local fm_epinpoint2 = Hyperspace.Blueprints:GetWeaponBlueprint("FM_RVS_PROJECTILE_BEAM_ENERGY_FOCUS_2")
local burstsToBeams = {}
burstsToBeams.RVS_BEAM_SHOTGUN_1 = pinpoint1
burstsToBeams.RVS_BEAM_SHOTGUN_2 = pinpoint1
burstsToBeams.RVS_BEAM_SHOTGUN_3 = pinpoint2
burstsToBeams.RVS_BEAM_SHOTGUN_1 = fm_epinpoint1
burstsToBeams.RVS_BEAM_SHOTGUN_2 = fm_epinpoint1
burstsToBeams.RVS_BEAM_SHOTGUN_3 = fm_epinpoint2
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
local popWeapons = {}
popWeapons.RVS_EMP_1 = {count = 2, countSuper = 2}
popWeapons.RVS_EMP_2 = {count = 2, countSuper = 2}
popWeapons.RVS_EMP_HEAVY_1 = {count = 4, countSuper = 6}
popWeapons.RVS_DRONE_EMP_LIGHT = {count = 1, countSuper = 1}
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
    local shieldPower = shipManager.shieldSystem.shields.power
    local popData = nil
    if pcall(function() popData = popWeapons[Hyperspace.Get_Projectile_Extend(projectile).name] end) and popData then
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
    local roomDamage = nil
    if pcall(function() roomDamage = roomDamageWeapons[projectile.extend.name] end) and roomDamage then
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
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(ShipManager, Projectile, Location, Damage, forceHit, shipFriendlyFire)
    if Projectile then
        local roomID = ShipManager.ship:GetSelectedRoomId(Location.x, Location.y, true)
        local system = ShipManager:GetSystemInRoom(roomID)
        local damageToDeal = emptyRoomDamage[Projectile.extend.name]
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
    local aoeDamage = aoeWeapons[projectile and projectile.extend.name] --Indexing with nil (no projectile) will return nil, otherwise returns projectile name index
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
systemTargetWeapons.RVS_ARTILLERY_EFFECTOR = sysWeights

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local thisShip = Hyperspace.ships(weapon.iShipId)
    local otherShip = Hyperspace.ships(1 - weapon.iShipId)
    local sysWeights = systemTargetWeapons[weapon.blueprint.name]
    if thisShip and otherShip and (thisShip.iShipId == 1 or weapon.isArtillery) and sysWeights then
        local sysTargets = {}
        local weightSum = 0
        
        -- Collect all player systems and their weights
        for system in vter(otherShip.vSystemList) do
            local sysId = system:GetId()
            if otherShip:HasSystem(sysId) then
                local weight = sysWeights[Hyperspace.ShipSystem.SystemIdToName(sysId)] or 1
                if weight > 0 then
                    weightSum = weightSum + weight
                    table.insert(sysTargets, {
                        id = sysId,
                        weight = weight
                    })
                end
            end
        end
        
        -- Pick a random system using the weights
        if #sysTargets > 0 then
            local rnd = math.random(weightSum);
            for i = 1, #sysTargets do
                if rnd <= sysTargets[i].weight then
                    projectile.target = otherShip:GetRoomCenter(otherShip:GetSystemRoom(sysTargets[i].id))
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
        Hyperspace.Sounds:PlaySoundMix(soundName, -1, true)
    end
  end 
  return Defines.Chain.CONTINUE, beamHit 
end)

-- Make a drone target enemy drones first before normal anti ship targetting
-- CV: I wrote this while I felt like crap and my brain was working at 0.1% capacity, god help whoever has to read it later
local function set_drone_destination(drone)
    local target = userdata_table(drone, "mods.ai.droneTarget").target
    if target then
        local shieldCenter = Hyperspace.ships(drone.currentSpace).ship:GetBaseEllipse().center
        drone.destinationLocation.x = (target.currentLocation.x - shieldCenter.x)*1.15 + shieldCenter.x
        drone.destinationLocation.y = (target.currentLocation.y - shieldCenter.y)*1.15 + shieldCenter.y
    end
end
local function aquire_drone_target(ship, droneName)
    local otherShip = Hyperspace.ships(1 - ship.iShipId)
    if otherShip then
        local target = nil
        for drone in vter(otherShip.spaceDrones) do
            if drone.deployed and drone.currentSpace == otherShip.iShipId and not drone.explosion.tracker.running and (drone.blueprint.typeName == "DEFENSE" or drone.blueprint.typeName == "SHIELD") then
                target = drone
                break
            end
        end
        for drone in vter(ship.spaceDrones) do
            if drone.blueprint and drone.blueprint.name == droneName then
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
    if drone.blueprint.name == "RVS_AI_MICROFIGHTER_INTERCEPTOR" then
        set_drone_destination(drone)
    end
end)
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if Hyperspace.ships.player then aquire_drone_target(Hyperspace.ships.player, "RVS_AI_MICROFIGHTER_INTERCEPTOR") end
    if Hyperspace.ships.enemy then aquire_drone_target(Hyperspace.ships.enemy, "RVS_AI_MICROFIGHTER_INTERCEPTOR") end
end)

--Make a drone target systems only
local function retarget_drone_to_system(ship, droneName)
    local otherShip = Hyperspace.ships(1 - ship.iShipId)
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
  if Projectile and Projectile.extend.name == "HARPOON_THINGY" then
    local destinationRoomNumber = ShipManager.ship:GetSelectedRoomId(Location.x, Location.y, true)
    local firingShip = Hyperspace.ships(Projectile.ownerId)
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
      Hyperspace.Sounds:PlaySoundMix("teleport", -1, false)
    end
  end
  return Defines.CHAIN_CONTINUE
end)
--Number of shots a drone may fire before it is destroyed
local limitShots = {}
limitShots.RVS_AI_MISSILE_1 = 7
limitShots.RVS_AI_MISSILE_2 = 5
limitShots.RVS_AI_MISSILE_3 = 15


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
            Hyperspace.Blueprints:GetWeaponBlueprint("RVS_BEAM_DEFENSE_SHOT"), 
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

-- Temporary drone handler
local function spawn_temp_drone(table)
    local name = table.name
    local ownerShip = table.ownerShip
    local targetShip = table.targetShip
    local targetLocation = table.targetLocation
    local shots = table.shots
    local position = table.position
    
    local drone = ownerShip:CreateSpaceDrone(Hyperspace.Blueprints:GetDroneBlueprint(name))
    drone.powerRequired = 0
    drone:SetMovementTarget(targetShip._targetable)
    drone:SetWeaponTarget(targetShip._targetable)
    drone.lifespan = shots or 2
    drone.powered = true
    drone:SetDeployed(true)
    drone.bDead = false
    if position then drone:SetCurrentLocation(position) end
    if targetLocation then drone.targetLocation = targetLocation end
    userdata_table(drone, "mods.ai.droneSwarm").clearOnJump = true
    return drone
end
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship.bJumping then
        for drone in vter(ship.spaceDrones) do
            if userdata_table(drone, "mods.ai.droneSwarm").clearOnJump then
                drone:SetDestroyed(true, false)
            end
        end
    end
end)

-- Spawn children for swarm drone
local shotsToSpawn = 2 -- Spawn a drone every shotsToSpawn shots
script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
    if drone.blueprint.name == "RVS_AI_MICROFIGHTER_SWARM" then
        local swarmData = userdata_table(drone, "mods.ai.droneSwarm")
        swarmData.shots = (swarmData.shots or shotsToSpawn) - 1
        if swarmData.shots <= 0 then
            swarmData.shots = shotsToSpawn
            local thisShip = Hyperspace.ships(drone.iShipId)
            local otherShip = Hyperspace.ships(1 - drone.iShipId)
            spawn_temp_drone{name = "RVS_AI_MICROFIGHTER_SWARM_CHILD", ownerShip = thisShip, targetShip = otherShip}
        end
    end
    return Defines.Chain.CONTINUE
end)

--RVS_AI_SWARM implementation (CHANGE NAME LATER)

--Spawn drone when drone is destroyed
local swarmChildProj = Hyperspace.Global.GetInstance():GetBlueprints():GetWeaponBlueprint("RVS_AI_MICROFIGHTER_SWARM_CHILD_PROJ_DUMMY")
script.on_internal_event(Defines.InternalEvents.DRONE_COLLISION,
function(Drone, Projectile, Damage, CollisionResponse)
    local thisShip = Hyperspace.ships(Drone.iShipId)
    local otherShip = Hyperspace.ships(1 - Drone.iShipId)
    if thisShip and otherShip and Damage.iIonDamage <= 0 and Damage.iDamage > 0 and otherShip:HasAugmentation("RVS_AI_SWARM") > 0 then --If drone would be destroyed and ship has drone spawning aug
        --Spawn drone at drone's location, or if the drone is in the other ship's space, spawn a projectile that will become the drone
        if thisShip.iShipId == Drone.currentSpace then
            spawn_temp_drone{name = "RVS_AI_MICROFIGHTER_SWARM_CHILD", ownerShip = otherShip, targetShip = thisShip, position = Drone.currentLocation}
        else
            local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
            local shipCenter = otherShip._targetable:GetShieldShape().center
            local heading = math.deg(math.atan(Drone.currentLocation.y - shipCenter.y, Drone.currentLocation.x - shipCenter.x))
            spaceManager:CreateMissile(swarmChildProj, Drone.currentLocation, Drone.currentSpace, Projectile.ownerId, thisShip:GetRandomRoomCenter(), Drone.iShipId, heading)
        end
    end
    return Defines.Chain.CONTINUE
end)
script.on_internal_event(Defines.InternalEvents.PROJECTILE_PRE, function(projectile)
    if projectile.extend.name == "RVS_AI_MICROFIGHTER_SWARM_CHILD_PROJ_DUMMY" and projectile.ownerId ~= projectile.currentSpace then
        local ship = Hyperspace.ships(projectile.ownerId)
        local otherShip = Hyperspace.ships(1 - projectile.ownerId)
        if ship and otherShip then
            spawn_temp_drone{name = "RVS_AI_MICROFIGHTER_SWARM_CHILD", ownerShip = ship, targetShip = otherShip, position = projectile.position}
        end
        projectile:Kill()
    end
end)


--V: Should this trigger on resist? Leaving like this for now unless told otherwise.
local function drone_vengeance(ship, damage)
    local rolledVengeance = math.random(100) <= 15 --15% chance
    if damage.iDamage > 0 and ship:HasAugmentation("RVS_AI_SWARM") > 0 and rolledVengeance then
        local otherShip = Hyperspace.ships(1 - ship.iShipId)
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
                weapon.radius = weapon.blueprint.radius - (15 * numDronesActive)
                weapon.radius = math.max(weapon.radius, 0)
            end
        end
    end
end)

local function RandomPointCircle(center, radius)
    local radius = radius * math.sqrt(math.random())
    local angle = 2 * math.pi * math.random()
    local x = center.x + radius * math.cos(angle)
    local y = center.y + radius * math.sin(angle)
    return x, y
end

local critStrip = Hyperspace.Resources:GetImageId "projectiles/rvs_flock_crit.png"
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE,
function(projectile, weapon)
    if weapon.blueprint.name == "RVS_FLOCK_GUN" then
        projectile.target.x, projectile.target.y = RandomPointCircle(weapon.lastTargets[0], weapon.radius)
        local ship = Hyperspace.ships(weapon.iShipId)
        local numDronesActive = 0
        for drone in vter(ship.spaceDrones) do
            if not drone.bDead and drone.powered then
                numDronesActive = numDronesActive + 1
            end
        end
        
        if math.random(6) <= numDronesActive then
            projectile.damage.iDamage = projectile.damage.iDamage * 2
            projectile.flight_animation.animationStrip = critStrip
        end
    end
end)

local function MakeSet(table)
    local set = {}
    for _, value in ipairs(table) do
        set[value] = true
    end
    return set
end

local scatterGun = {}
--for every gun do the following, the stats of the projectiles fired will be modified with a chance% chance by sys sysDamgae and pers persDamage
scatterGun.RVS_LASER_BURST_SCATTER_1 = { damage={iSystemDamage = 1, iPersDamage = 1}, chance=25}
scatterGun.RVS_LASER_BURST_SCATTER_2 = { damage={iSystemDamage = 1, iPersDamage = 1}, chance=25}
scatterGun.RVS_SHOTGUN_SCATTER = { damage={iSystemDamage = 1, iPersDamage = 1}, chance=25}
scatterGun.RVS_DRONE_LASER_SCATTER = { damage={iSystemDamage = 1, iPersDamage = 1}, chance=25}

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE,
function(projectile, weapon)
  local gun
  pcall(function()gun = scatterGun[weapon.blueprint.name] end)
  if gun and math.random(0,99)< gun.chance then
    for k, v in pairs(gun.damage) do
      projectile.damage[k] = projectile.damage[k] + v
    end
  end
end)

--Rules:
--Never target the same room twice, unless the ship has less than 3 rooms
--Always target systems, unless the ship has less than 3 systems
--Always target a defensive, offensive, and "other" system, unless the ship does not have a system to fit one or more of said categories
local defensiveSystemIds = MakeSet {0, 1, 6, 10}
local offensiveSystemIds = MakeSet {3, 4, 9, 11, 14, 15}
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE,
function(projectile, weapon)
    if weapon.blueprint.name == "RVS_ARTILLERY_AI" and weapon.queuedProjectiles:size() == 2 then --Target projectiles when first projectile fires
        local ship = Hyperspace.ships(projectile.targetId)
        local roomList = ship.ship.vRoomList
        local defensive, offensive, other, empty = {}, {}, {}, {} --Create target candidate tables
        for roomID = 0, Hyperspace.ShipGraph.GetShipInfo(projectile.targetId):RoomCount() - 1 do
            local system = ship:GetSystemInRoom(roomID)
            if not system then
                table.insert(empty, roomID) --List of systemless room IDs
            elseif defensiveSystemIds[system:GetId()] then
                table.insert(defensive, roomID) --List of defensive system room IDs
            elseif offensiveSystemIds[system:GetId()] then
                table.insert(offensive, roomID) --List of offensive system room IDs
            else
                table.insert(other, roomID) --List of other system room IDs
            end
        end
        projectile.target = ship:GetRoomCenter(PopRandom(defensive) or PopRandom(offensive) or PopRandom(other) or PopRandom(empty) or 0) --Prioritize defensive systems, then systems, then empty rooms
        weapon.queuedProjectiles[0].target = ship:GetRoomCenter(PopRandom(offensive) or PopRandom(other) or PopRandom(defensive) or PopRandom(empty) or 0) --Prioritize offensive systems, then systems, then empty rooms
        weapon.queuedProjectiles[1].target = ship:GetRoomCenter(PopRandom(other) or PopRandom(defensive) or PopRandom(offensive) or PopRandom(empty) or 0) --Prioritize other systems, then systems, then empty rooms
    end
end)

--Evasion Armor
script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR,
function(ShipManager, dodge)
    dodge = dodge + ShipManager:GetAugmentationValue("RVS_DODGE_ARMOR")
    return Defines.Chain.CONTINUE, dodge
end)

script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR,
function(ShipManager, dodge)
    if ShipManager:HasAugmentation("RVS_ANTI_GRAVITY_ENGINE") > 0 then
        local engines = ShipManager:GetSystem(1)
        local piloting = ShipManager:GetSystem(6)
        if not piloting or piloting:GetEffectivePower() == 0 then
            dodge = dodge + 15
        elseif not engines or engines:GetEffectivePower() == 0 then
            dodge = dodge + 5
        end
    end
    return Defines.Chain.CONTINUE, dodge
end)

local plasmaProjectiles = MakeSet {
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
            local hullDamageChance = firePercent / 3    --R4: this was 2, I changed this to 3, hopefully that isn't bad? this does mean lower chance yes yes?

            if math.random(100) <= hullDamageChance then
                Damage.iDamage = Damage.iDamage + 1
            end
        end
    end
    return Defines.CHAIN_CONTINUE, forceHit, shipFriendlyFire
end)

-- Custom drone orbit
-- Ported from escort duty mod
local escortEllipse = {
    center = {
        x = 203,
        y = 430
    }, 
    a = 172,
    b = 320
}
local droneSpeedFactor = 1.6
local activeDroneIds = {}

local calculate_coord_offset = function(angleFromCenter)
    local angleCos = escortEllipse.b*math.cos(angleFromCenter)
    local angleSin = escortEllipse.a*math.sin(angleFromCenter)
    local denom = math.sqrt(angleCos^2 + angleSin^2)
    return (escortEllipse.a*angleCos)/denom, (escortEllipse.b*angleSin)/denom
end

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    -- Iterate through all defense drones if the ship is AI renegade
    local isEscort = 0
    if pcall(function() isEscort = math.max(
            Hyperspace.ships.enemy:HasEquipment("SHIP RVSRB_AI_CRUISER_3_NORMAL"),
            Hyperspace.ships.enemy:HasEquipment("SHIP RVSRB_AI_CRUISER_3_CHALLENGE"),
            Hyperspace.ships.enemy:HasEquipment("SHIP RVSRB_AI_CRUISER_3_EXTREME"),
            Hyperspace.ships.enemy:HasEquipment("SHIP RVSRB_AI_CRUISER_3_CHAOS")
        ) end) and isEscort > 0 then
        local stillActive = {}
        for drone in vter(Hyperspace.ships.enemy.spaceDrones) do
            if drone.deployed and drone.blueprint.typeName == "DEFENSE" then
                stillActive[drone.selfId] = true
                local xOffset = nil
                local yOffset = nil
                
                -- Set drone location to a random point on the ellipse if just deployed
                if not activeDroneIds[drone.selfId] then
                    activeDroneIds[drone.selfId] = true
                    xOffset, yOffset = calculate_coord_offset((Hyperspace.random32()%360)*(math.pi/180))
                    drone:SetCurrentLocation(Hyperspace.Pointf(
                        escortEllipse.center.x + xOffset,
                        escortEllipse.center.y + yOffset))
                end

                -- Make the drone orbit the fake ellipse
                if drone.powered then
                    local lookAhead = drone.blueprint.speed*Hyperspace.FPS.SpeedFactor/droneSpeedFactor
                    xOffset, yOffset = calculate_coord_offset(math.atan(
                        drone.currentLocation.y - escortEllipse.center.y,
                        drone.currentLocation.x - escortEllipse.center.x))
                    local xIntersect = escortEllipse.center.x + xOffset
                    local yIntersect = escortEllipse.center.y + yOffset
                    local tanAngle = math.atan((escortEllipse.b^2/escortEllipse.a^2)*(xOffset/yOffset))
                    if (drone.currentLocation.y < escortEllipse.center.y) then
                        drone.destinationLocation = Hyperspace.Pointf(
                            xIntersect + lookAhead*math.cos(tanAngle),
                            yIntersect - lookAhead*math.sin(tanAngle))
                    else
                        drone.destinationLocation = Hyperspace.Pointf(
                            xIntersect - lookAhead*math.cos(tanAngle),
                            yIntersect + lookAhead*math.sin(tanAngle))
                    end
                end
            end
        end

        -- Clean out inactive drone IDs
        for droneId in pairs(activeDroneIds) do
            if not stillActive[droneId] then
                activeDroneIds[droneId] = nil
            end
        end
    end
end)

-- RVS_PROJECTOR_AVATAR implementation
local get_random_ship_system = function(ship)
    local systems = {}
    for system in vter(ship.vSystemList) do
        table.insert(systems, system:GetRoomId())
    end
    return systems[math.random(#systems)]
end

local refresh_boarding_AI = function(targetShip)
    local assaultCount = 2
    local decoyCount = 2
    for crewmen in vter(targetShip.vCrewList) do
        if crewmen.blueprint.name == "rvs_ai_hologram_assault" then
            crewmen.extend.deathTimer:Start(30) --Reset their death Time
            crewmen.health.first = crewmen.health.second --Reset their health
            assaultCount = assaultCount - 1
        end
        if crewmen.blueprint.name == "rvs_ai_hologram_decoy" then
            crewmen.extend.deathTimer:Start(30) --Reset their death Time
            crewmen.health.first = crewmen.health.second --Reset their health
            decoyCount = decoyCount - 1
        end
        if crewmen.blueprint.name == "rvs_ai_hologram" then
            crewmen.health.first = crewmen.health.second --Reset their health
            decoyCount = decoyCount - 1
        end
    end

    local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
    local eventParser = Hyperspace.CustomEventsParser.GetInstance()

    if targetShip.iShipId == 1 then
        if assaultCount == 2 and decoyCount == 2 then
            eventParser:LoadEvent(worldManager,"RVS_PROJECTOR_SPAWN_DECOYATTACKER",false,-1)
            return end

        for i = 0, assaultCount - 1 do
            eventParser:LoadEvent(worldManager,"RVS_PROJECTOR_SPAWN_ATTACKER_SINGLE",false,-1)
        end
        for i = 0, decoyCount - 1 do
            eventParser:LoadEvent(worldManager,"RVS_PROJECTOR_SPAWN_DECOY_SINGLE",false,-1)
        end
    else
        if assaultCount == 2 and decoyCount == 2 then
            eventParser:LoadEvent(worldManager,"RVS_PROJECTOR_ENEMY_SPAWN_DECOYATTACKER",false,-1)
            return end

        for i = 0, assaultCount - 1 do
            eventParser:LoadEvent(worldManager,"RVS_PROJECTOR_ENEMY_SPAWN_ATTACKER_SINGLE",false,-1)
        end
        for i = 0, decoyCount - 1 do
            eventParser:LoadEvent(worldManager,"RVS_PROJECTOR_ENEMY_SPAWN_DECOY_SINGLE",false,-1)
        end
    end
    
end

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, 
function(shipManager, projectile, location, Damage, shipFriendlyFire)
    if projectile and projectile.extend.name == "RVS_PROJECTOR_AVATAR" then
        refresh_boarding_AI(shipManager)
    end
    return Defines.Chain.CONTINUE
end)

-- Small buff/debuff applied on evasion while projector is active, only for the player
script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR, 
function(shipManager, value)
    local playerShip = Hyperspace.ships.player
    if not playerShip or not playerShip.weaponSystem then return end
    for weapon in vter(playerShip.weaponSystem.weapons) do
        if weapon.blueprint.name == "RVS_PROJECTOR_AVATAR" and weapon.powered then
            if shipManager.iShipId == 0 then
                value = value + 5
            else
                value = value - 5
            end
        end
    end
    return Defines.Chain.CONTINUE, value
end)

-- Pre-half ignited projector for the player on jump
script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, 
function(shipManager)
    if not shipManager.iShipId == 1 then return end
    for weapon in vter(shipManager.weaponSystem.weapons) do
        if weapon.blueprint.name == "RVS_PROJECTOR_AVATAR" and weapon.powered then
            weapon.cooldown.first = weapon.cooldown.second/2
        end
    end
end)

-- Player method
script.on_game_event("RVS_PROJECTOR_SPAWN_DELAY", false, function()
    local shipManager = Hyperspace.ships.player
    local shipOpponent = Hyperspace.ships.enemy
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.blueprint.name == "rvs_ai_hologram_decoy" or crewmem.blueprint.name == "rvs_ai_hologram_assault" then
            local tpRoomId = get_random_ship_system(shipOpponent)
            local deathTime = Hyperspace.TimerHelper()
            deathTime:Start(30)
            crewmem.extend.deathTimer = deathTime
            if not pcall(function() crewmem.extend:InitiateTeleport(1, tpRoomId, 0) end) then
                crewmem:Kill(true)
            end
        end
    end
end)

-- Enemy method
script.on_game_event("RVS_PROJECTOR_ENEMY_SPAWN_DELAY", false, function()
    local shipManager = Hyperspace.ships.enemy
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.blueprint.name == "rvs_ai_hologram_decoy" or crewmem.blueprint.name == "rvs_ai_hologram_assault" then
            local deathTime = Hyperspace.TimerHelper()
            deathTime:Start(30)
            crewmem.extend.deathTimer = deathTime
        end
    end
end)