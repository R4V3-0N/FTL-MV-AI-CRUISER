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
        spaceManager:CreateBeam(
            beamReplacement,
            projectile.position,
            projectile.currentSpace,
            projectile.ownerId,
            projectile.target, projectile.target,
            projectile.destinationSpace,
            1, projectile.heading).entryAngle = projectile.entryAngle
        projectile:Kill()
        return true
    end
end, INT_MAX)
