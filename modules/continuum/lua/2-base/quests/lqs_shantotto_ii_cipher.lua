-----------------------------------
-- Ohohoho! A Test Most Dire! (Lv75)
-----------------------------------
-- Quest to obtain Shantotto II Cipher
-- Shantotto tests the player's worthiness
-- through three trials:
--   1. Collect elemental crystals (trade)
--   2. Defeat her magical construct (combat)
--   3. Retrieve her research notes (investigation)
-----------------------------------
-- !setvar [LQS]SHANTOTTO_II_CIPHER 0
-- Shantottos shadow   !pos 118 -2 110 239 (Windurst Walls)
-- Examiner Spawner    !pos -20 0.5 -60 194 (Outer Horutoto Ruins)
-- Research Notes      !pos 110 -2 120 239 (Windurst Walls)
-----------------------------------
local m = Module:new('a-q_shan2_cipher')

local info =
{
    name   = 'Ohohoho! A Test Most Dire!',
    author = 'Zenith',
    var    = '[LQS]SHANTOTTO_II_CIPHER',
    reward = xi.item.CIPHER_OF_SHANTOTTOS_ALTER_EGO_II,
}

local shantottoQuest     = 'Shantottos shadow'
local examinerSpawner    = 'Magical Presence'
local shantottosExaminer = 'Shantottos Examiner'
local researchNotes      = 'Research Notes'

LQS.add(m, {
    info     = info,
    entities =
    {
        ['Windurst_Walls'] =
        {
            -- Shantotto NPC (always present) - uses Shantotto II trust model
            {
                name    = shantottoQuest,
                type    = xi.objType.NPC,
                look    = 3110,
                pos     = { 118, -2, 110, 64 },
                marker  = LQS.SIDE_QUEST,
                default =
                {
                    'Ohohohohoho! What do you want, and why do you stare?',
                    ' Speak up quickly, if you dare!',
                },
            },
            -- Research notes spawner
            {
                name    = researchNotes,
                marker  = LQS.MAIN_QUEST,
                pos     = { 110, -2, 120, 0 },
                default = LQS.NOTHING,
            },
        },
        ['Outer_Horutoto_Ruins'] =
        {
            -- Combat spawner point
            {
                name    = examinerSpawner,
                marker  = LQS.MAIN_QUEST,
                pos     = { 420.0106, -10.5000, 743.2542, 0 },
                default = LQS.NOTHING,
            },
            -- Combat challenge mob (uses Queen_of_Swords cardian as base)
            {
                name  = shantottosExaminer,
                type  = xi.objType.MOB,
                pos   = { 420.0106, -10.5000, 743.2542, 0 },
                base  = { 194, 64 },
                level = 75,
            },
        },
    },
    steps =
    {
        -- Step 0: Talk to Shantotto to accept quest
        {
            check            = LQS.checks({ level = 75 }),
            [shantottoQuest] = LQS.dialog({
                quest = info.name,
                event =
                {
                    { emote = xi.emote.LAUGH },
                    'Ohohohohoho! You dare approach the great Shantotto?',
                    ' Then listen well, for my words are not hollow!',
                    { delay = 1000 },
                    { emote = xi.emote.POINT },
                    'You seek my power in cipher form?',
                    ' Then prove yourself beyond the norm!',
                    { delay = 500 },
                    'First bring crystals, five in all,',
                    ' Fire, Ice, Lightning, heed my call!',
                    ' Water flowing, Earth so tight,',
                    ' Return with these to prove your might!',
                },
            }),
        },

        -- Step 1: Crystal collection trade
        {
            [shantottoQuest] =
            {
                onTrigger = LQS.dialog({
                    step  = false,
                    event =
                    {
                        { emote = xi.emote.THINK },
                        'The crystals five, you must procure,',
                        ' Or from this trial, you will not endure!',
                        'Fire and Ice, Lightning bright,',
                        ' Water flowing, Earth of might!',
                        'Trade them all to me at once,',
                        ' Or be forever labeled a dunce!',
                    },
                }),
                onTrade = LQS.trade({
                    required =
                    {
                        { xi.item.FIRE_CRYSTAL, 1 },
                        { xi.item.ICE_CRYSTAL, 1 },
                        { xi.item.LIGHTNING_CRYSTAL, 1 },
                        { xi.item.WATER_CRYSTAL, 1 },
                        { xi.item.EARTH_CRYSTAL, 1 },
                    },
                    declined =
                    {
                        { emote = xi.emote.NO },
                        'These items will not do at all!',
                        ' Bring the crystals that I call!',
                    },
                    accepted =
                    {
                        { emote = xi.emote.LAUGH },
                        'Ohohohohoho! The elements you have brought to me,',
                        ' Show basic knowledge, as I see!',
                        { delay = 500 },
                        'But mere crystals do not prove your worth,',
                        ' Now face my guard, prove your mirth!',
                        { delay = 500 },
                        'In the Outer Horutoto Ruins you must go,',
                        ' There my Examiner waits, friend or foe!',
                    },
                }),
            },
        },

        -- Step 2: Direct player to combat zone
        {
            [shantottoQuest] = LQS.dialog({
                step  = false,
                event =
                {
                    'To Outer Horutoto Ruins, make haste!',
                    ' My Examiner awaits, no time to waste!',
                    'Prove your combat worth down there,',
                    ' Then return to me without a care!',
                },
            }),
            [examinerSpawner] = LQS.menu({
                title   = 'A magical presence lingers here. Investigate?',
                spawn   = { shantottosExaminer },
                options =
                {
                    {
                        'Leave it alone',
                    },
                    {
                        'Investigate',
                        true,
                    },
                },
            }),
            [shantottosExaminer] = LQS.defeat({
                mobs    = { shantottosExaminer },
                spawner = examinerSpawner,
                exp     = 1000,
            }),
        },

        -- Step 3: Post-combat, return to Shantotto
        {
            [examinerSpawner] = LQS.dialog({
                step  = false,
                event = { 'The magical presence has faded...' },
            }),
            [shantottoQuest] = LQS.dialog({
                event =
                {
                    { emote = xi.emote.CHEER },
                    'Ohohohohoho! You have proved your might,',
                    ' In glorious combat, what a sight!',
                    { delay = 500 },
                    'But strength alone will not earn my trust,',
                    ' Intelligence and cunning are a must!',
                    { emote = xi.emote.THINK },
                    { delay = 1000 },
                    'Seek my notes near the Orastery halls,',
                    ' Hidden knowledge awaits your calls!',
                    'Return with proof of scholarly art,',
                    ' And my cipher shall then depart!',
                },
            }),
        },

        -- Step 4: Research notes retrieval
        {
            [shantottoQuest] = LQS.dialog({
                step  = false,
                event =
                {
                    'The notes await near Orastery\'s keep,',
                    ' Find them well, do not fall asleep!',
                },
            }),
            [researchNotes] = LQS.menu({
                title   = 'Take Shantotto\'s research notes?',
                options =
                {
                    {
                        'Leave them',
                    },
                    {
                        'Take the notes',
                        {
                            { message = 'You obtained Shantotto\'s research notes!' },
                        },
                    },
                },
            }),
        },

        -- Step 5: Quest completion
        {
            [researchNotes] = LQS.dialog({
                step  = false,
                event = { 'You already took the research notes.' },
            }),
            [shantottoQuest] = LQS.dialog({
                reward = info.reward,
                quest  = info.name,
                event  =
                {
                    { emote = xi.emote.LAUGH },
                    'Ohohohohohohoho! At last you have shown,',
                    ' That skills and wisdom you have grown!',
                    { delay = 500 },
                    'You have passed my trials, every one,',
                    ' And now my cipher shall be won!',
                    { emote = xi.emote.CHEER },
                    { delay = 500 },
                    'Take this cipher, use it well,',
                    ' And of my greatness, always tell!',
                    { delay = 2000 },
                    { emote = xi.emote.LAUGH },
                    'Ohohohohohoho!',
                },
            }),
        },

        -- Step 6: Post-completion dialog
        {
            [shantottoQuest] = LQS.dialog({
                step  = false,
                event =
                {
                    'You have my cipher, now begone!',
                    ' Use my power well from dawn to dawn!',
                    { emote = xi.emote.GOODBYE },
                },
            }),
        },
    },
})

return m
