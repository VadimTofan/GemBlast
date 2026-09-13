local TestRunner = require("tests.TestRunner")
local MovePlanner = require("Game.MovePlanner")

local function cell(gemType)
    return { gemType = gemType }
end

local function patternedBoard()
    local board = {}

    for row = 1, 8 do
        board[row] = {}
        for column = 1, 8 do
            board[row][column] = cell(((row * 2 + column) % 7) + 1)
        end
    end

    return board
end

local function validSwapBoard()
    local board = patternedBoard()
    board[1][1] = cell(1)
    board[1][2] = cell(2)
    board[1][3] = cell(1)
    board[2][2] = cell(1)

    return board
end

-- Move planning
TestRunner.describe("MovePlanner.Plan", function()
    TestRunner.it("explodes a matched bomb while creating a four-match special", function()
        -- Given
        local board = patternedBoard()
        board[4][2] = cell(2)
        board[4][3] = cell(2)
        board[4][4] = cell(2)
        board[4][5] = cell(3)
        board[3][5] = { gemType = 2, special = "explosive" }

        -- When
        local plan = MovePlanner.Plan(board, 0, 3, 5, 4, 5)

        -- Then
        local clearStep = plan.steps[2]
        TestRunner.assertTrue(plan.accepted)
        TestRunner.assertEqual("bomb", clearStep.effects[1].effectType)
        TestRunner.assertEqual(4, clearStep.effects[1].row)
        TestRunner.assertEqual(5, clearStep.effects[1].column)
        TestRunner.assertEqual("directional", clearStep.special.specialType)
        TestRunner.assertFalse(clearStep.special.row == 4
            and clearStep.special.column == 5)
    end)

    TestRunner.it("explodes a stationary bomb in a four-gem match", function()
        -- Given
        local board = patternedBoard()
        board[4][2] = cell(2)
        board[4][3] = { gemType = 2, special = "explosive" }
        board[4][4] = cell(2)
        board[4][5] = cell(3)
        board[3][5] = cell(2)

        -- When
        local plan = MovePlanner.Plan(board, 0, 3, 5, 4, 5)

        -- Then
        local clearStep = plan.steps[2]
        TestRunner.assertTrue(plan.accepted)
        TestRunner.assertEqual("bomb", clearStep.effects[1].effectType)
        TestRunner.assertEqual(4, clearStep.effects[1].row)
        TestRunner.assertEqual(3, clearStep.effects[1].column)
        TestRunner.assertEqual("directional", clearStep.special.specialType)
    end)

    TestRunner.it("uses the moved directional bomb swap axis", function()
        -- Given
        local board = patternedBoard()
        board[4][4] = { gemType = 2, special = "directional" }
        board[4][5] = cell(3)
        board[3][5] = cell(2)
        board[5][5] = cell(2)

        -- When
        local plan = MovePlanner.Plan(board, 0, 4, 4, 4, 5)

        -- Then
        local effects = plan.steps[2].effects
        TestRunner.assertTrue(plan.accepted)
        TestRunner.assertEqual("lineBomb", effects[1].effectType)
        TestRunner.assertEqual("horizontal", effects[1].direction)
    end)

    TestRunner.it("creates a spark without a gem color", function()
        -- Given
        local board = patternedBoard()
        for column = 1, 4 do
            board[4][column] = cell(2)
        end
        board[4][5] = cell(3)
        board[4][6] = cell(2)
        math.randomseed(86420)

        -- When
        local plan = MovePlanner.Plan(board, 0, 4, 6, 4, 5)

        -- Then
        local settledBoard = plan.steps[3].board
        TestRunner.assertTrue(plan.accepted)
        TestRunner.assertEqual("color", settledBoard[4][5].special)
        TestRunner.assertEqual(nil, settledBoard[4][5].gemType)
    end)

    TestRunner.it("plans a valid move without changing the live board", function()
        -- Given
        local board = validSwapBoard()
        local originalGem = board[1][2].gemType

        -- When
        local plan = MovePlanner.Plan(board, 0, 1, 2, 2, 2)

        -- Then
        TestRunner.assertTrue(plan.accepted)
        TestRunner.assertEqual(originalGem, board[1][2].gemType)
        TestRunner.assertEqual("swap", plan.steps[1].kind)
        TestRunner.assertEqual("clear", plan.steps[2].kind)
        TestRunner.assertEqual(0, #plan.steps[2].effects)
        TestRunner.assertEqual("settle", plan.steps[3].kind)
    end)

    TestRunner.it("plans an invalid swap that returns to its origin", function()
        -- Given
        local board = patternedBoard()

        -- When
        local plan = MovePlanner.Plan(board, 0, 1, 1, 1, 2)

        -- Then
        TestRunner.assertFalse(plan.accepted)
        TestRunner.assertEqual(1, #plan.steps)
        TestRunner.assertFalse(plan.steps[1].valid)
        TestRunner.assertEqual(0, plan.finalScore)
    end)

    TestRunner.it("animates a double-bomb swap before its larger clear", function()
        -- Given
        local board = {
            {
                { gemType = 1 }, { gemType = 2 }, { gemType = 3 },
                { gemType = 4 }, { gemType = 5 }, { gemType = 6 },
                { gemType = 7 }, { gemType = 1 },
            },
        }
        for row = 2, 8 do
            board[row] = {}
            for column = 1, 8 do
                board[row][column] = {
                    gemType = ((row * 2 + column) % 7) + 1,
                }
            end
        end
        board[4][4] = { gemType = 1, special = "explosive" }
        board[4][5] = { gemType = 2, special = "explosive" }
        math.randomseed(24680)

        -- When
        local plan = MovePlanner.Plan(board, 0, 4, 4, 4, 5)

        -- Then
        local clearedCount = 0
        for _ in pairs(plan.steps[2].positions) do
            clearedCount = clearedCount + 1
        end

        TestRunner.assertTrue(plan.accepted)
        TestRunner.assertEqual("swap", plan.steps[1].kind)
        TestRunner.assertEqual("clear", plan.steps[2].kind)
        TestRunner.assertEqual(25, clearedCount)
        TestRunner.assertEqual(1, #plan.steps[2].effects)
        TestRunner.assertEqual(
            "bombCombo",
            plan.steps[2].effects[1].effectType
        )
        TestRunner.assertEqual(4, plan.steps[2].effects[1].row)
        TestRunner.assertEqual(5, plan.steps[2].effects[1].column)
    end)

    TestRunner.it("passes a spark trigger to the clear animation", function()
        -- Given
        local board = {}
        for row = 1, 8 do
            board[row] = {}
            for column = 1, 8 do
                board[row][column] = {
                    gemType = ((row + column) % 7) + 1,
                }
            end
        end
        board[1][1] = { gemType = 1, special = "color" }
        board[1][2] = { gemType = 6 }
        math.randomseed(13579)

        -- When
        local plan = MovePlanner.Plan(board, 0, 1, 1, 1, 2)

        -- Then
        local effects = plan.steps[2].effects
        TestRunner.assertEqual(1, #effects)
        TestRunner.assertEqual("spark", effects[1].effectType)
        TestRunner.assertEqual(1, effects[1].row)
        TestRunner.assertEqual(2, effects[1].column)
        TestRunner.assertEqual(6, effects[1].gemType)
    end)

    TestRunner.it("animates every converted bomb in a spark-bomb swap", function()
        -- Given
        local board = {}
        for row = 1, 8 do
            board[row] = {}
            for column = 1, 8 do
                board[row][column] = { gemType = 1 }
            end
        end
        board[4][4] = { gemType = 7, special = "color" }
        board[4][5] = { gemType = 2, special = "explosive" }
        board[2][2] = { gemType = 2 }
        board[7][7] = { gemType = 2 }
        math.randomseed(97531)

        -- When
        local plan = MovePlanner.Plan(board, 0, 4, 4, 4, 5)

        -- Then
        local bombEffects = 0
        for _, effect in ipairs(plan.steps[2].effects) do
            if effect.effectType == "bomb" then
                bombEffects = bombEffects + 1
            end
        end

        TestRunner.assertTrue(plan.accepted)
        TestRunner.assertEqual("spark", plan.steps[2].effects[1].effectType)
        TestRunner.assertEqual(3, bombEffects)
        TestRunner.assertTrue(plan.steps[2].positions["1:1"])
        TestRunner.assertTrue(plan.steps[2].positions["8:8"])
    end)

    TestRunner.it("uses the special-preserving reshuffle path", function()
        -- Given
        local file = assert(io.open("Game/MovePlanner.lua", "r"))
        local source = file:read("*a")
        file:close()

        -- When
        local preservesSpecials = source:find(
            "Board.Reshuffle(board, random)",
            1,
            true
        ) ~= nil

        -- Then
        TestRunner.assertTrue(preservesSpecials)
    end)
end)
