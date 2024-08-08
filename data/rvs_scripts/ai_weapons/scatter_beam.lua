-- Replace burst projectile with beam for shotgun pinpoints
local pinpoint1 = Hyperspace.Blueprints:GetWeaponBlueprint("RVS_PROJECTILE_BEAM_FOCUS_1")
local pinpoint2 = Hyperspace.Blueprints:GetWeaponBlueprint("RVS_PROJECTILE_BEAM_FOCUS_2")
local fm_epinpoint1 = Hyperspace.Blueprints:GetWeaponBlueprint("FM_RVS_PROJECTILE_BEAM_ENERGY_FOCUS_1")
local fm_epinpoint2 = Hyperspace.Blueprints:GetWeaponBlueprint("FM_RVS_PROJECTILE_BEAM_ENERGY_FOCUS_2")
local burstsToBeams = {}
burstsToBeams.RVS_BEAM_SHOTGUN_1 = pinpoint1
burstsToBeams.RVS_BEAM_SHOTGUN_2 = pinpoint1
burstsToBeams.RVS_BEAM_SHOTGUN_3 = pinpoint2
burstsToBeams.FM_RVS_SPLITTER_ENERGY_1 = fm_epinpoint1
burstsToBeams.FM_RVS_SPLITTER_ENERGY_2 = fm_epinpoint1
burstsToBeams.FM_RVS_SPLITTER_ENERGY_3 = fm_epinpoint2
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local beamReplacement = burstsToBeams[weapon.blueprint.name]
    if beamReplacement then
        local spaceManager = Hyperspace.App.world.space
        local beam = spaceManager:CreateBeam(
            beamReplacement, projectile.position, projectile.currentSpace, projectile.ownerId,
            projectile.target, Hyperspace.Pointf(projectile.target.x, projectile.target.y + 1),
            projectile.destinationSpace, 1, projectile.heading)
        beam.sub_start.x = 500*math.cos(projectile.entryAngle)
        beam.sub_start.y = 500*math.sin(projectile.entryAngle) 
        projectile:Kill()
    end
end)
