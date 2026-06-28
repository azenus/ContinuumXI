-----------------------------------
-- Dynamis: prevent mob linking
-- In Dynamis, ShouldForceLink() forces all mobs into one party, but the engage-spread in
-- OnMobFight is gated by CanLink(), which returns false when MOBMOD_NO_LINK > 0. Setting
-- NO_LINK on every Dynamis mob therefore stops the pack from linking.
-- Also replaces dynamis_mob_respawn.sql: bumps regular-trash respawn 600s -> 3600s.
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('c-m_dynamis_no_link')

local regularRespawn  = 600  -- default respawn for regular Dynamis trash (seconds)
local extendedRespawn = 3600 -- desired respawn for regular Dynamis trash (1 hour)

-- Per-spawn enforcement: nearly every Dynamis mob calls xi.dynamis.mobInfo in onMobSpawn.
m:addOverride('xi.dynamis.mobInfo', function(mob)
    super(mob)

    mob:setMobMod(xi.mobMod.NO_LINK, 1)
end)

-- Zone-load pass for the 10 main Dynamis zones: covers every loaded mob (even ones whose
-- script never calls mobInfo) and applies the regular-trash respawn change.
m:addOverride('xi.dynamis.zoneOnInitialize', function(zone)
    super(zone)

    for _, mob in pairs(zone:getMobs()) do
        mob:setMobMod(xi.mobMod.NO_LINK, 1)

        if mob:getRespawnTime() == regularRespawn then
            mob:setRespawnTime(extendedRespawn)
        end
    end
end)

return m
