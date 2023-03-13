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

function helloWorld()
	log ("The script has loaded successfully, welcome commander")
end
script.on_game_event("START_BEACON_PRESELECT", false, helloWorld)

function empShieldImpact (ship, projectile, damage, response) --this functions arguement is looking at a bunch of things that I have yet to comprehend but it should cover all the basics I need for when the projectile hits a shield
    if Hyperspace.Get_Projectile_Extend(projectile).name == "RVS_EMP_1" then            --this gives me an output that tells me which projectile hit a shield which it then compares to the blueprint of the weapon, if it equals rvs_emp_1 then it continues. If not it stops
		local pop = Hyperspace.Damage()	--we've assigned the object Hyperspace.Damage as pop, which we made local to avoid any conflicts with other mods.
		pop.iDamage = 2
		ship.shieldSystem:CollisionReal(projectile.position.x, projectile.position.y, pop, true)
       -- ship:CollisionShield(projectile.position, projectile.position, pop, false)
		log(response.collision_type)
    end
end
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, empShieldImpact) --checks on internal event, that event is defined as a shield collission, which when it detects a shield collission it then calls for empShieldImpact


-- This is fixed with a method provided by Vert, I still have yet to understand the logic of this. But their notes are here to provide me closure when I am wise enough to comprehend it. I have retroactively applied comments from them with a prefix
function empHullImpact (ship, projectile, damage, response) 
    if Hyperspace.Get_Projectile_Extend(projectile).name == "RVS_EMP_1" then
       local empHullHit = Hyperspace.Damage()
       empHullHit.iIonDamage = 1 --R4: Will set it to 1 ion damage for now along with 1 regular damage
       Hyperspace.Get_Projectile_Extend(projectile).name = "" --Vert: if the name of the active projectile is blank, the first line will evaluate to false and empHullImpact won't do anything within the next call of DamageArea

       ship:DamageArea(projectile.position, empHullHit, true) --Vert: Can now call DamageArea safely

        Hyperspace.Get_Projectile_Extend(projectile).name = "RVS_EMP_1" --Vert: set the name back for any future functions to use
    end
end
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, empHullImpact) 