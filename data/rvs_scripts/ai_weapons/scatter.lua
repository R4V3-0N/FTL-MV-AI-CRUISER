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
    if gun and math.random(0, 99) < gun.chance then
        for k, v in pairs(gun.damage) do
            projectile.damage[k] = projectile.damage[k] + v
        end
    end
end)
