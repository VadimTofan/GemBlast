local TestRunner = require("tests.TestRunner")
local Persistence = require("Persistence")

-- Saved data migration
TestRunner.describe("Persistence.SelectSavedData", function()
    TestRunner.it("uses legacy data when the new store is empty", function()
        -- Given
        local legacyData = { score = 750 }

        -- When
        local selected = Persistence.SelectSavedData(nil, legacyData)

        -- Then
        TestRunner.assertEqual(legacyData, selected)
    end)

    TestRunner.it("prefers data already saved under the new identity", function()
        -- Given
        local currentData = { score = 1000 }
        local legacyData = { score = 750 }

        -- When
        local selected = Persistence.SelectSavedData(currentData, legacyData)

        -- Then
        TestRunner.assertEqual(currentData, selected)
    end)
end)

-- Saved data validation
TestRunner.describe("Persistence.Normalize", function()
    TestRunner.it("enables level-up emotes by default", function()
        -- Given
        local savedData = nil

        -- When
        local normalized = Persistence.Normalize(savedData)

        -- Then
        TestRunner.assertTrue(normalized.levelUpEmotesEnabled)
    end)

    TestRunner.it("preserves explicitly disabled level-up emotes", function()
        -- Given
        local Board = require("Game.Board")
        local savedData = {
            board = Board.Create(),
            levelUpEmotesEnabled = false,
        }

        -- When
        local normalized = Persistence.Normalize(savedData)

        -- Then
        TestRunner.assertFalse(normalized.levelUpEmotesEnabled)
    end)

    TestRunner.it("enables flight auto-toggle by default", function()
        -- Given
        local savedData = nil

        -- When
        local normalized = Persistence.Normalize(savedData)

        -- Then
        TestRunner.assertTrue(normalized.autoToggleEnabled)
    end)

    TestRunner.it("preserves an explicitly disabled flight auto-toggle", function()
        -- Given
        local Board = require("Game.Board")
        local savedData = {
            board = Board.Create(),
            autoToggleEnabled = false,
        }

        -- When
        local normalized = Persistence.Normalize(savedData)

        -- Then
        TestRunner.assertFalse(normalized.autoToggleEnabled)
    end)

    TestRunner.it("disables the public leaderboard by default", function()
        -- Given
        local savedData = nil

        -- When
        local normalized = Persistence.Normalize(savedData)

        -- Then
        TestRunner.assertFalse(normalized.publicLeaderboardEnabled)
    end)

    TestRunner.it("replaces a malformed board with a new game", function()
        -- Given
        local savedData = { board = { { { gemType = 99 } } }, score = 50 }

        -- When
        local normalized = Persistence.Normalize(savedData)

        -- Then
        TestRunner.assertEqual(8, #normalized.board)
        TestRunner.assertEqual(0, normalized.score)
    end)

    TestRunner.it("preserves a valid settled game", function()
        -- Given
        math.randomseed(12345)
        local Board = require("Game.Board")
        local board = Board.Create()
        local savedData = {
            board = board,
            score = 750,
            soundEnabled = false,
            leaderboardShown = false,
            autoToggleEnabled = true,
            closeInCombatEnabled = true,
            publicLeaderboardEnabled = true,
        }

        -- When
        local normalized = Persistence.Normalize(savedData)

        -- Then
        TestRunner.assertEqual(750, normalized.score)
        TestRunner.assertFalse(normalized.soundEnabled)
        TestRunner.assertFalse(normalized.leaderboardShown)
        TestRunner.assertTrue(normalized.autoToggleEnabled)
        TestRunner.assertTrue(normalized.closeInCombatEnabled)
        TestRunner.assertTrue(normalized.publicLeaderboardEnabled)
    end)

    TestRunner.it("preserves a saved board with a colorless spark", function()
        -- Given
        local Board = require("Game.Board")
        local board = Board.Create()
        board[4][4] = { special = "color" }
        local savedData = {
            board = board,
            score = 750,
        }

        -- When
        local normalized = Persistence.Normalize(savedData)

        -- Then
        TestRunner.assertEqual(board, normalized.board)
        TestRunner.assertEqual(750, normalized.score)
        TestRunner.assertEqual(nil, normalized.board[4][4].gemType)
    end)

    TestRunner.it("preserves a saved board with a directional bomb", function()
        -- Given
        local Board = require("Game.Board")
        local board = Board.Create()
        board[4][4] = { gemType = 3, special = "directional" }
        local savedData = { board = board, score = 750 }

        -- When
        local normalized = Persistence.Normalize(savedData)

        -- Then
        TestRunner.assertEqual(board, normalized.board)
        TestRunner.assertEqual("directional", normalized.board[4][4].special)
    end)

    TestRunner.it("keeps valid encoded leaderboard entries", function()
        -- Given
        local ScorePacket = require("Game.ScorePacket")
        local encoded = ScorePacket.Encode({
            accountId = "account000000001",
            sessionId = "session000000001",
            sequence = 4,
            name = "Jaina-Proudmoore",
            guid = "Player-1-ABCDEF01",
            score = 200000,
            level = 28,
        })
        local Board = require("Game.Board")
        local savedData = {
            board = Board.Create(),
            partyTopScores = {
                account000000001 = { encoded = encoded, updatedAt = 50 },
            },
            publicTopScores = {
                account000000001 = { encoded = encoded, updatedAt = 50 },
            },
        }

        -- When
        local normalized = Persistence.Normalize(savedData)

        -- Then
        TestRunner.assertEqual(
            200000,
            normalized.partyTopScores.account000000001.score
        )
        TestRunner.assertEqual(
            200000,
            normalized.publicTopScores.account000000001.score
        )
    end)

    TestRunner.it("drops leaderboard entries with invalid checksums", function()
        -- Given
        local Board = require("Game.Board")
        local savedData = {
            board = Board.Create(),
            partyTopScores = {
                attacker = { encoded = "B1:not-valid", updatedAt = 50 },
            },
        }

        -- When
        local normalized = Persistence.Normalize(savedData)

        -- Then
        TestRunner.assertEqual(nil, normalized.partyTopScores.attacker)
    end)

    TestRunner.it("seeds only the public leaderboard", function()
        -- Given
        local savedData = nil

        -- When
        local normalized = Persistence.Normalize(savedData)

        -- Then
        local publicCount = 0
        for _ in pairs(normalized.publicTopScores) do
            publicCount = publicCount + 1
        end

        TestRunner.assertEqual(0, next(normalized.partyTopScores) and 1 or 0)
        TestRunner.assertEqual(10, publicCount)
    end)

    TestRunner.it("applies a higher score from a weekly seed update", function()
        -- Given
        local Board = require("Game.Board")
        local ScorePacket = require("Game.ScorePacket")
        local seeds = require("Game.PublicLeaderboardSeeds").GetEntries()
        local seed = seeds[1]
        local lowerEncoded = ScorePacket.Encode({
            accountId = seed.accountId,
            sessionId = "oldseedsession01",
            sequence = 1,
            name = seed.name,
            guid = seed.guid,
            score = seed.score - 100,
            level = seed.level,
        })
        local savedData = {
            board = Board.Create(),
            publicTopScores = {
                [seed.accountId] = { encoded = lowerEncoded, updatedAt = 1 },
            },
        }

        -- When
        local normalized = Persistence.Normalize(savedData)

        -- Then
        TestRunner.assertEqual(
            seed.score,
            normalized.publicTopScores[seed.accountId].score
        )
    end)

    TestRunner.it("preserves a saved score that is higher than its seed", function()
        -- Given
        local Board = require("Game.Board")
        local ScorePacket = require("Game.ScorePacket")
        local Scoring = require("Game.Scoring")
        local seeds = require("Game.PublicLeaderboardSeeds").GetEntries()
        local seed = seeds[1]
        local higherScore = seed.score + 1000
        local higherLevel = Scoring.GetLevel(higherScore)
        local higherEncoded = ScorePacket.Encode({
            accountId = seed.accountId,
            sessionId = "savedscorehigh01",
            sequence = 2,
            name = seed.name,
            guid = seed.guid,
            score = higherScore,
            level = higherLevel,
        })
        local savedData = {
            board = Board.Create(),
            publicTopScores = {
                [seed.accountId] = { encoded = higherEncoded, updatedAt = 2 },
            },
        }

        -- When
        local normalized = Persistence.Normalize(savedData)

        -- Then
        TestRunner.assertEqual(
            higherScore,
            normalized.publicTopScores[seed.accountId].score
        )
    end)
end)
