local TestRunner = require("tests.TestRunner")
local ChannelOrder = require("Game.ChannelOrder")

-- Moving a custom channel behind the existing channel list
TestRunner.describe("ChannelOrder.MoveToLast", function()
    TestRunner.it("moves the target through later channel slots", function()
        -- Given
        local swaps = {}

        -- When
        ChannelOrder.MoveToLast(1, { 1, 2, 5, 7 }, function(first, second)
            swaps[#swaps + 1] = { first, second }
        end)

        -- Then
        TestRunner.assertEqual(3, #swaps)
        TestRunner.assertEqual(1, swaps[1][1])
        TestRunner.assertEqual(2, swaps[1][2])
        TestRunner.assertEqual(2, swaps[2][1])
        TestRunner.assertEqual(5, swaps[2][2])
        TestRunner.assertEqual(5, swaps[3][1])
        TestRunner.assertEqual(7, swaps[3][2])
    end)

    TestRunner.it("does nothing when the target is already last", function()
        -- Given
        local swapCount = 0

        -- When
        ChannelOrder.MoveToLast(7, { 1, 2, 5, 7 }, function()
            swapCount = swapCount + 1
        end)

        -- Then
        TestRunner.assertEqual(0, swapCount)
    end)

    TestRunner.it("does nothing when the target is absent", function()
        -- Given
        local swapCount = 0

        -- When
        ChannelOrder.MoveToLast(4, { 1, 2, 5, 7 }, function()
            swapCount = swapCount + 1
        end)

        -- Then
        TestRunner.assertEqual(0, swapCount)
    end)
end)
