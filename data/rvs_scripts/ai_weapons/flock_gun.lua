local vter = mods.multiverse.vter

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
