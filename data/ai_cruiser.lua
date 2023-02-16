if not mods or not mods.vertexutil then
    error("Couldn't find Vertex Tags and Utility Functions! Make sure it's above mods which depend on it in the Slipstream load order", 2)
end

local vter = mods.vertexutil.vter

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
