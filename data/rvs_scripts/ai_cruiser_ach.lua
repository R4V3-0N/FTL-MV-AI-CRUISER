----------------------
-- HELPER FUNCTIONS --
----------------------

local vter = mods.multiverse.vter
local string_starts = mods.multiverse.string_starts

local function should_track_achievement(achievement, ship, shipClassName)
    return ship and
           Hyperspace.App.world.bStartedGame and
           Hyperspace.CustomAchievementTracker.instance:GetAchievementStatus(achievement) < Hyperspace.Settings.difficulty and
           string_starts(ship.myBlueprint.blueprintName, shipClassName)
end

local function current_sector()
    return Hyperspace.App.world.starMap.worldLevel + 1
end

local function count_ship_achievements(achPrefix)
    local count = 0
    for i = 1, 3 do
        if Hyperspace.CustomAchievementTracker.instance:GetAchievementStatus(achPrefix.."_"..tostring(i)) > -1 then
            count = count + 1
        end
    end
    return count
end

-------------------------
-- ACHIEVEMENT UNLOCKS --
-------------------------

-- AI Cruiser Achievements --
-- Easy
do
    local function check_holo_revive_ach(ship)
        return ship.iShipId == 0 and
               Hyperspace.playerVariables.loc_holos_revived >= 4 and
               should_track_achievement("ACH_SHIP_RVSP_AI_1", ship, "PLAYER_SHIP_RVSP_AI")
    end
    script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
        if check_holo_revive_ach(ship) then
            Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_RVSP_AI_1", false)
        end
    end)
end

-- Normal
do
    local function check_no_crew_support_ach(ship)
        return ship.iShipId == 0 and
               current_sector() >= 8 and
               not ship:HasSystem(2) and
               not ship:HasSystem(5) and
               not ship:HasSystem(13) and
               should_track_achievement("ACH_SHIP_RVSP_AI_2", ship, "PLAYER_SHIP_RVSP_AI")
    end
    script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
        if check_no_crew_support_ach(ship) then
            Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_RVSP_AI_2", false)
        end
    end)
end

-- Hard
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local playerShip = Hyperspace.ships.player
    if should_track_achievement("ACH_SHIP_RVSP_AI_3", playerShip, "PLAYER_SHIP_RVSP_AI") then
        local vars = Hyperspace.playerVariables
        local enemyShip = Hyperspace.ships.enemy
        if enemyShip and enemyShip._targetable.hostile and not (enemyShip.bDestroyed or playerShip.bJumping) then -- In combat?
            vars.loc_ai_ach_in_combat = 1
            if vars.loc_ai_ach_missed_this_fight == 0 then -- Check for miss if we haven't found one already
                for projectile in vter(Hyperspace.App.world.space.projectiles) do
                    if projectile.ownerId == 0 and projectile.damage.selfId ~= -1 and projectile.missed and not projectile.death_animation.tracker.running then
                        vars.loc_ai_ach_missed_this_fight = 1
                    end
                end
            end
        else
            -- If we just ended combat by destroying the ship with no miss, incriment counter
            if vars.loc_ai_ach_in_combat == 1 and enemyShip and enemyShip.bDestroyed and vars.loc_ai_ach_missed_this_fight == 0 then
                vars.loc_ai_ach_no_miss_count = vars.loc_ai_ach_no_miss_count + 1
                if vars.loc_ai_ach_no_miss_count >= 22 then
                    Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_RVSP_AI_3", false)
                    return
                end
            end
            vars.loc_ai_ach_in_combat = 0
            vars.loc_ai_ach_missed_this_fight = 0
        end
    end
end)

-- Rebel Cruiser Achievements --
-- Easy "HOME BY ANY OTHER NAME"
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship.iShipId == 0 and current_sector() <= 5 and should_track_achievement("ACH_SHIP_RVSP_REBEL_ALT_1", ship, "PLAYER_SHIP_RVSP_REBEL_ALT") then
        if ship:CountCrew(false) >= 8 then
            Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_RVSP_REBEL_ALT_1", false)
        end
    end
end)

-- Medium "SHATTERED MIRROR"
local function defeatRebel()
    if should_track_achievement("ACH_SHIP_RVSP_REBEL_ALT_2", Hyperspace.ships.player, "PLAYER_SHIP_RVSP_REBEL_ALT") then
        Hyperspace.playerVariables.loc_high_rebels_killed = Hyperspace.playerVariables.loc_high_rebels_killed + 1
        if Hyperspace.playerVariables.loc_high_rebels_killed >= 3 then
            Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_RVSP_REBEL_ALT_2", false)
        end
    end
end

script.on_game_event("A55_DEFEAT", false, defeatRebel)    -- A55 boss fight
script.on_game_event("AUTO_POWERCORE_DEFEAT", false, defeatRebel) -- Engineer Mothership Fight
script.on_game_event("AUTO_POWERCORE_SAVE", false, defeatRebel)   -- Engineer Mothership Fight (Saved. Included this as you still fought against them and "won")
script.on_game_event("DYNASTY_DREADNAUGHT_VICTORY", false, defeatRebel)   -- Dynasty Autodreadnought fight
script.on_game_event("FED_MEMORIAL_DESTROY", false, defeatRebel)  -- Fed Sector Rebel Gunboat Fight
script.on_game_event("FED_MEMORIAL_DEAD_CREW", false, defeatRebel)
script.on_game_event("CURA_DEFEATED", false, defeatRebel)    --CURA
script.on_game_event("CYRA_DEFEAT", false, defeatRebel)   -- Cyra cruiser stuff
script.on_game_event("CYRA_DEFEAT_JERRY", false, defeatRebel)
script.on_game_event("FLAGSHIP_CONSTRUCTION_WIN", false, defeatRebel) --Rebel sector Flagship construction
script.on_game_event("SHOWDOWN_WIN", false, defeatRebel) --MFK Flagship True End Win
-- "SHIP_CHAOS_FLEET_FLAGSHIP" from event "FLEET_CHAOS_FLAGSHIP", "NEBULA_FLEET_CHAOS_FLAGSHIP"
script.on_game_event("ESTATE_LEGION_DEFEAT", false, defeatRebel)    --Zenith Legion event at Estate
script.on_game_event("ALKALI_LEGION_DEFEATED", false, defeatRebel)   --Morph Legion event at Science
script.on_game_event("RVS_FREIGHTER_CONVOY_WIN", false, defeatRebel)   --GO BALLISTIC! 2 Cruiser fight

-- Hard "HOW DID WE GET HERE"
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local playerShip = Hyperspace.ships.player
    local checkAch = should_track_achievement("ACH_SHIP_RVSP_REBEL_ALT_3", playerShip, "PLAYER_SHIP_RVSP_REBEL_ALT") and
                     playerShip.iIntruderCount >= 1 and
                     playerShip.fuel_count <= 0 and
                     playerShip.fireSpreader.count >= 1
    if checkAch then
        for projectile in vter(Hyperspace.App.world.space.projectiles) do -- Janky way to check if under ASB fire
            if projectile.extend and projectile.extend.name == "PDS_SHOT" then
                Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_RVSP_REBEL_ALT_3", false)
                return
            end
        end
    end
end)

-------------------------------------
-- LAYOUT UNLOCKS FOR ACHIEVEMENTS --
-------------------------------------

-- AI CRUISER STUFF --
local achLayoutUnlocks = {
    {
        achPrefix = "ACH_SHIP_RVSP_AI",
        unlockShip = "PLAYER_SHIP_RVSP_AI_3"
    }
}

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local unlockTracker = Hyperspace.CustomShipUnlocks.instance
    for _, unlockData in ipairs(achLayoutUnlocks) do
        if not unlockTracker:GetCustomShipUnlocked(unlockData.unlockShip) and count_ship_achievements(unlockData.achPrefix) >= 2 then
            unlockTracker:UnlockShip(unlockData.unlockShip, false)
        end
    end
end)

--  ALT REBEL CRUISER STUFF  --
-- Bellow is my bird brained attempt to do a thing
local achLayoutUnlocks = {
    {
        achPrefix = "ACH_SHIP_RVSP_REBEL_ALT",
        unlockShip = "PLAYER_SHIP_RVSP_REBEL_ALT_3"
    }
}

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local unlockTracker = Hyperspace.CustomShipUnlocks.instance
    for _, unlockData in ipairs(achLayoutUnlocks) do
        if not unlockTracker:GetCustomShipUnlocked(unlockData.unlockShip) and count_ship_achievements(unlockData.achPrefix) >= 2 then
            unlockTracker:UnlockShip(unlockData.unlockShip, false)
        end
    end
end)
