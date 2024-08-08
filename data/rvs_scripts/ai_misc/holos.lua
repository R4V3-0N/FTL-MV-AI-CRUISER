local vter = mods.multiverse.vter
local holoSpecies = mods.rvsai.holoSpecies

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
