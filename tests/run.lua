package.path = "./?.lua;./?/init.lua;" .. package.path

local TestRunner = require("tests.TestRunner")

-- TestRunner
TestRunner.describe("TestRunner", function()
    TestRunner.it("compares equal values", function()
        -- Given
        local expected = "gem"

        -- When
        local actual = "gem"

        -- Then
        TestRunner.assertEqual(expected, actual)
    end)
end)

require("tests.BoardTest")
require("tests.ResolutionTest")
require("tests.ScoringTest")
require("tests.SpecialGemTest")
require("tests.MovePlannerTest")
require("tests.SpecialEffectsAnimationTest")
require("tests.AnimationDirectorTest")
require("tests.PersistenceTest")
require("tests.ControllerTest")
require("tests.UISpecialMarkerTest")
require("tests.InputTest")
require("tests.HintTest")
require("tests.MinimapPositionTest")
require("tests.AddOnMetadataTest")
require("tests.ReleaseWorkflowTest")
require("tests.UIFrameLayerTest")
require("tests.UIMenuTest")
require("tests.AnnouncementTest")
require("tests.CommunicationTest")
require("tests.LeaderboardTest")
require("tests.ScorePacketTest")
require("tests.ScoreSessionTest")
require("tests.LeaderboardStoreTest")
require("tests.PublicLeaderboardSeedsTest")
require("tests.PublicLeaderboardTest")
require("tests.ChannelOrderTest")
require("tests.PublicLeaderboardIntegrationTest")
require("tests.UILeaderboardTest")
require("tests.AutoToggleTest")

TestRunner.finish()
