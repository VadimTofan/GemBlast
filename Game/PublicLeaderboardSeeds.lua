local PublicLeaderboardSeeds = {}
local _, addon = ...

local ScorePacket = type(addon) == "table" and addon.ScorePacket
    or require("Game.ScorePacket")
local Scoring = type(addon) == "table" and addon.Scoring
    or require("Game.Scoring")

local SEED_VERSION = 1
local SEED_SESSION_ID = "seedversion000001"
local seedDefinitions = {
    { "Fortytwo", "seedv1fortytwo", "BB5EED01", 23840 },
    { "Misteni", "seedv1misteni", "BB5EED02", 21670 },
    { "Redfer", "seedv1redfer", "BB5EED03", 19320 },
    { "Loukoumaki", "seedv1loukoumaki", "BB5EED04", 17150 },
    { "Azzor", "seedv1azzor", "BB5EED05", 14860 },
    { "Pagomouno", "seedv1pagomouno", "BB5EED06", 12640 },
    { "Velainor", "seedv1velainor", "BB5EED07", 10380 },
    { "Palioxamoura", "seedv1palioxamoura", "BB5EED08", 7890 },
    { "Zarlas", "seedv1zarlas", "BB5EED09", 4620 },
    {
        "Catbury-Kazzak",
        "6aa19d82e283bf5c516e",
        "0D2826FB",
        282440,
        "Player-1305-0D2826FB",
    },
}

local function createEntry(definition)
    local name, accountId, guidSuffix, score, guid = unpack(definition)
    local level = Scoring.GetLevel(score)
    local scoreData = {
        accountId = accountId,
        sessionId = SEED_SESSION_ID,
        sequence = SEED_VERSION,
        name = name,
        guid = guid or "Player-0-" .. guidSuffix,
        score = score,
        level = level,
    }

    scoreData.encoded = ScorePacket.Encode(scoreData)

    return scoreData
end

function PublicLeaderboardSeeds.GetEntries()
    local entries = {}

    for index, definition in ipairs(seedDefinitions) do
        entries[index] = createEntry(definition)
    end

    return entries
end

if type(addon) == "table" then
    addon.PublicLeaderboardSeeds = PublicLeaderboardSeeds
end

return PublicLeaderboardSeeds
