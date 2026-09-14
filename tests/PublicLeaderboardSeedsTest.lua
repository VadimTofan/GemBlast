local TestRunner = require("tests.TestRunner")
local ScorePacket = require("Game.ScorePacket")
local Scoring = require("Game.Scoring")
local PublicLeaderboardSeeds = require("Game.PublicLeaderboardSeeds")

-- Version 1 public leaderboard seeds
TestRunner.describe("PublicLeaderboardSeeds", function()
    TestRunner.it("includes Catbury's recorded score with the default players", function()
        -- Given
        local expectedNames = {
            Fortytwo = true,
            Misteni = true,
            Redfer = true,
            Loukoumaki = true,
            Azzor = true,
            Pagomouno = true,
            Velainor = true,
            Palioxamoura = true,
            Zarlas = true,
            ["Catbury-Kazzak"] = true,
        }

        -- When
        local entries = PublicLeaderboardSeeds.GetEntries()

        -- Then
        TestRunner.assertEqual(10, #entries)
        for _, entry in ipairs(entries) do
            TestRunner.assertTrue(expectedNames[entry.name])
            expectedNames[entry.name] = nil
            if entry.name == "Catbury-Kazzak" then
                TestRunner.assertEqual("6aa19d82e283bf5c516e", entry.accountId)
                TestRunner.assertEqual("Player-1305-0D2826FB", entry.guid)
                TestRunner.assertEqual(191670, entry.score)
                TestRunner.assertEqual(27, entry.level)
            end
        end
        for _ in pairs(expectedNames) do
            TestRunner.assertTrue(false)
        end
    end)

    TestRunner.it("uses stable valid packets and reachable levels", function()
        -- Given
        local firstRead = PublicLeaderboardSeeds.GetEntries()

        -- When
        local secondRead = PublicLeaderboardSeeds.GetEntries()

        -- Then
        for index, entry in ipairs(firstRead) do
            local decoded = ScorePacket.Decode(entry.encoded)
            local expectedLevel = Scoring.GetLevel(entry.score)

            TestRunner.assertEqual(entry.encoded, secondRead[index].encoded)
            TestRunner.assertEqual(entry.name, decoded.name)
            TestRunner.assertEqual(entry.score, decoded.score)
            TestRunner.assertEqual(expectedLevel, decoded.level)
        end
    end)
end)
