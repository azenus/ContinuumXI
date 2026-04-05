--@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 0,
    parameters = 's'
}

-- Toggle for cooldown functionality
local useCooldown = true

-- Table of city coordinates by name
local cityCoordinates = {
    ["Windhurst"] = {x = -230.70, y = -119.47, z = -0.25, zoneId = 239}, -- Windy Woods South
    ["Sandoria"] = {x = 159.62, y = 159.56, z = -2.0, zoneId = 230}, -- Sandoria South
    ["Bastok"] = {x = -177, y = -30, z = -8.0, zoneId = 235}, -- Bastok Market
    ["Norg"] = {x = -20.80, y = -47.36, z = 0.23, zoneId = 252}, -- Norg
    ["Kazham"] = {x = -4.43, y = 5.410, z = -3.18, zoneId = 250}, -- Kazham
    ["Mhaura"] = {x = -4.43, y = 5.410, z = -3.18, zoneId = 249}, -- Mhaura
    ["Rabao"] = {x = 0, y = -117.97, z = -4.0, zoneId = 247}, -- Rabao
    ["Jeuno"] = {x = 21.62, y = 51.84, z = -1.0, zoneId = 245}, -- Jeuno
    ["Selbina"] = {x = 17.98, y = 98.68, z = -14.56, zoneId = 248}, -- Selbina
    ["Ramuh"] = {x = 538.63, y = 505.98, z = 13.76, zoneId = 202}, -- Ramuh
    ["Garuda"] = {x = -368.07, y = -383.89, z = -0.06, zoneId = 201}, -- Garuda
    ["Shiva"] = {x = 556.48, y = 592.55, z = 0.29, zoneId = 203}, -- Shiva
    ["Titan"] = {x = -538.76, y = -511.05, z = 1.34, zoneId = 209}, -- Titan
    ["Leviathan"] = {x = 563.19, y = 553.16, z = 36.64, zoneId = 211}, -- Levi
    ["Ifrit"] = {x = -714.08, y = -607.91, z = 0.0, zoneId = 207}, -- Ifrit
    ["Maat"] = {x = 4.12, y = 117.97, z = 3.10, zoneId = 243}, -- Maat
    ["Shantotto"] = {x = 122.72, y = 113.61, z = -3.0, zoneId = 239}, -- Shantotto
    ["Feiyin"] = {x = 101.01, y = 135.81, z = -20.250, zoneId = 111}, -- Fei Yin
    ["Purgonorgo"] = {x = 521.60, y = 563.00, z = -3, zoneId = 44} -- Purgonorgo
}

-- Cooldown tracker
local cooldowns = {}

-- Error message function
local function error(player, msg)
    player:printToPlayer(msg)
    player:printToPlayer('Usage: !teleport <city name>')
end

-- Teleport function
local teleportToCity = function(player, city)
    player:printToPlayer(string.format('Teleporting to %s...', city.zoneId))
    player:timer(500, function(playerArg)
        -- Swap Y and Z coordinates if needed
        playerArg:setPos(city.x, city.z, city.y, 0, city.zoneId)
    end)
end

-- Command trigger
commandObj.onTrigger = function(player, cityName)
    -- Validate input
    if not cityName or not cityCoordinates[cityName] then
        error(player, 'Invalid city name. Please choose Windhurst, Sandoria, or Bastok.')
        return
    end

    local playerId = player:getID()
    local currentTime = os.time()
    local playerPermission = player:getGMLevel() -- Assuming getGMLevel() fetches the permission level

    -- Check cooldown if enabled and the player does not have permission 1 or higher
    if useCooldown and playerPermission < 1 then
        if cooldowns[playerId] and currentTime < cooldowns[playerId] then
            local remainingTime = cooldowns[playerId] - currentTime
            player:printToPlayer(string.format('You must wait %d seconds before using this command again.', remainingTime))
            return
        end

        -- Set cooldown
        cooldowns[playerId] = currentTime + 300 -- 5 minutes (300 seconds)
    end

    -- Get city details
    local city = cityCoordinates[cityName]

    -- Teleport the player
    teleportToCity(player, city)
end

return commandObj
