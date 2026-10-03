---@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 0,
    parameters = 'i'
}

-- Toggle for cooldown functionality
local useCooldown = false

-- Table of camp coordinates by camp ID
local campCoordinates = {
    [1] = {x = 913.84, y = -324.19, z = -0.30, zoneId = 103}, -- Dunes Lizards
    [2] = {x = -40.59, y = 261.74, z = -19.83, zoneId = 126}, -- Qufim H7
    [3] = {x = 368.28, y = -21.83, z = -32.37, zoneId = 197}, -- Crawlers Nest K7
    [4] = {x = -380.03, y = 393.75, z = -12.0, zoneId = 200},  -- Garlaige Citidel
    [5] = {x = -21.14, y = 6.10, z = 0.07, zoneId = 167}, -- Bostaunieux Oubliette
    [6] = {x = -20.48, y = -239.75, z = -20.0, zoneId = 174}, -- 174	Kuftal Tunnel
  
    -- Add more camps as needed
}

-- Cooldown tracker
local cooldowns = {}

-- Error message function
local function error(player, msg)
    player:printToPlayer(msg)
    player:printToPlayer('Usage: !camp <camp number>')
end

-- Teleport function
local teleportToCamp = function(player, camp)
    player:printToPlayer(string.format('Teleporting to camp %d...', camp.zoneId))
    player:timer(500, function(playerArg)
        -- Swap Y and Z coordinates if needed
        playerArg:setPos(camp.x, camp.z, camp.y, 0, camp.zoneId)
    end)
end


-- Command trigger
commandObj.onTrigger = function(player, campId)
    -- Validate input
    if not campId or not campCoordinates[campId] then
        error(player, 'Invalid camp number. Please choose a valid camp ID.')
        return
    end

    local playerId = player:getID()
    local currentTime = os.time()

    -- Check cooldown if enabled
    if useCooldown then
        if cooldowns[playerId] and currentTime < cooldowns[playerId] then
            local remainingTime = cooldowns[playerId] - currentTime
            player:printToPlayer(string.format('You must wait %d seconds before using this command again.', remainingTime))
            return
        end

        -- Set cooldown
        cooldowns[playerId] = currentTime + 300 -- 5 minutes (300 seconds)
    end

    -- Get camp details
    local camp = campCoordinates[campId]

    -- Teleport the player
    teleportToCamp(player, camp)
end

return commandObj
