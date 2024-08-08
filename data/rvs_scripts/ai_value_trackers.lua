local vter = mods.multiverse.vter
local function race_exists(race)
    return Hyperspace.Blueprints:GetCrewBlueprint(race).name == race
end
local function bool_to_num(bool)
    return bool and 1 or 0
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
local holoSpecies = mods.rvsai.holoSpecies

-- Check if TRC's mutants are available
script.on_init(function(newGame)
    if newGame and race_exists("mutant") then Hyperspace.playerVariables.loc_ai_mutants_exist = 1 end
end)

-- Track whether we're in a nebula or a nebula with an ion storm
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local space = Hyperspace.App.world.space
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
