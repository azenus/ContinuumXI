-----------------------------------
-- Trust: Prishe / Ulmia -- CoP unlock fix
-- Base LSB gates these two CoP trusts behind `getCurrentMission(COP) > DAWN`, which
-- requires Chains of Promathia to be fully COMPLETED. On this server that only happens
-- through the Apocalypse Nigh epilogue quest chain, so a player who has defeated
-- Promathia (and even claimed their reward ring) still cannot obtain the trusts.
--
-- Per BG Wiki (Promathia Mission 8-4), both are meant to be obtained DURING mission
-- 8-4 "Dawn":
--   - Ulmia: after defeating Promathia          -> mission Status >= 2 (already correct)
--   - Prishe: after finishing the final cutscenes -> mission Status >= 5 (already correct)
-- and the wiki warns that progressing into the CoP epilogue quests can actually PREVENT
-- these cutscenes -- the opposite of requiring completion.
--
-- Fix: relax the mission gate from `> DAWN` to `>= DAWN`, so the trusts unlock while the
-- player is on Dawn (currentMission == DAWN) and remain obtainable afterwards, so they
-- can never become permanently missable. The Status thresholds and the trust-permit
-- requirement are preserved exactly as base.
-----------------------------------
local m = Module:new('c_trust_cop_unlock')

m:addOverride('xi.server.onServerStart', function()
    super()

    xi.module.modifyInteractionEntry('scripts/quests/hiddenQuests/Trust_Prishe', function(quest)
        quest.sections[1].check = function(player)
            return xi.settings.main.ENABLE_TRUST_QUESTS == 1 and
                xi.trust.hasPermit(player) and
                not player:hasSpell(xi.magic.spell.PRISHE) and
                player:getCurrentMission(xi.mission.log_id.COP) >= xi.mission.id.cop.DAWN and
                xi.mission.getVar(player, xi.mission.log_id.COP, xi.mission.id.cop.DAWN, 'Status') >= 5
        end
    end)

    xi.module.modifyInteractionEntry('scripts/quests/hiddenQuests/Trust_Ulmia', function(quest)
        quest.sections[1].check = function(player)
            return xi.settings.main.ENABLE_TRUST_QUESTS == 1 and
                xi.trust.hasPermit(player) and
                not player:hasSpell(xi.magic.spell.ULMIA) and
                player:getCurrentMission(xi.mission.log_id.COP) >= xi.mission.id.cop.DAWN and
                xi.mission.getVar(player, xi.mission.log_id.COP, xi.mission.id.cop.DAWN, 'Status') >= 2
        end
    end)
end)

return m
