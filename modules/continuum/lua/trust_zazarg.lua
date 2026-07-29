-----------------------------------
-- Trust: Zazarg
-- Completes the "Fist of the People" reward chain. Upstream LSB only grants the
-- Stoneserpent Shocktrooper title and Imperial Standing; the retail step where the
-- player returns to Fari-Wari to learn Trust: Zazarg was never implemented (there is
-- no Trust_Zazarg hidden quest and addSpell(ZAZARG) is called nowhere in base code).
--
-- After completing Fist of the People, speaking to Fari-Wari in Aht Urhgan Whitegate
-- plays event 5093 (Fari-Wari, NPC 16982364) and teaches Trust: Zazarg (spell 924).
--
-- Implemented as a modifyInteractionEntry override so the base quest file stays
-- untouched (upstream-merge friendly). Gated like the other trust quests: trusts
-- enabled and the player holds a trust permit.
-----------------------------------
local m = Module:new('c_trust_zazarg')

local zazargTrustEvent = 5093 -- Fari-Wari cutscene that teaches Trust: Zazarg

m:addOverride('xi.server.onServerStart', function()
    super()

    xi.module.modifyInteractionEntry('scripts/quests/ahtUrhgan/Fist_of_the_People', function(quest)
        local whitegateID = zones[xi.zone.AHT_URHGAN_WHITEGATE]

        table.insert(quest.sections,
        {
            check = function(player, status, vars)
                return status == xi.questStatus.QUEST_COMPLETED and
                    xi.settings.main.ENABLE_TRUST_QUESTS == 1 and
                    xi.trust.hasPermit(player) and
                    not player:hasSpell(xi.magic.spell.ZAZARG)
            end,

            [xi.zone.AHT_URHGAN_WHITEGATE] =
            {
                ['Fari-Wari'] =
                {
                    onTrigger = function(player, npc)
                        return quest:event(zazargTrustEvent)
                    end,
                },

                onEventFinish =
                {
                    [zazargTrustEvent] = function(player, csid, option, npc)
                        player:addSpell(xi.magic.spell.ZAZARG, { silentLog = true })
                        player:messageSpecial(whitegateID.text.YOU_LEARNED_TRUST, 0, xi.magic.spell.ZAZARG)
                    end,
                },
            },
        })
    end)
end)

return m
