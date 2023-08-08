----------------------
-- HELPER FUNCTIONS --
----------------------

local vter = mods.vertexutil.vter

local function string_starts(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

local function should_track_achievement(achievement, ship, shipClassName)
    return ship and
           Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and
           Hyperspace.CustomAchievementTracker.instance:GetAchievementStatus(achievement) < Hyperspace.Settings.difficulty and
           string_starts(ship.myBlueprint.blueprintName, shipClassName)
end

local function current_sector()
    return Hyperspace.Global.GetInstance():GetCApp().world.starMap.worldLevel + 1
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
                for projectile in vter(Hyperspace.Global.GetInstance():GetCApp().world.space.projectiles) do
                    if projectile.ownerId == 0 and projectile.damage.selfId ~= -1 and projectile.missed and not projectile.death_animation.tracker.running then
                        vars.loc_ai_ach_missed_this_fight = 1
                    end
                end
            end
        else
            -- If we just ended combat by destroying the ship with no miss, incriment counter
            if vars.loc_ai_ach_in_combat == 1 and enemyShip and enemyShip.bDestroyed and vars.loc_ai_ach_missed_this_fight == 0 then
                vars.loc_ai_ach_no_miss_count = vars.loc_ai_ach_no_miss_count + 1
                if vars.loc_ai_ach_no_miss_count >= 8 then
                    Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_RVSP_AI_3", false)
                    return
                end
            end
            vars.loc_ai_ach_in_combat = 0
            vars.loc_ai_ach_missed_this_fight = 0
        end
    end
end)

-------------------------------------
-- LAYOUT UNLOCKS FOR ACHIEVEMENTS --
-------------------------------------

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
