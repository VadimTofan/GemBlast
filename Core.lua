local addonName, addon = ...

local events = CreateFrame("Frame")
local SCORE_SYNC_INTERVAL = 30
local publicLeaderboardAvailable =
    WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

local function getPlayerName()
    local name, realm = UnitFullName("player")
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end

    return name
end

local function generateId()
    return string.format(
        "%08x%06x%06x",
        GetServerTime() % 2147483647,
        math.random(0, 16777215),
        math.random(0, 16777215)
    )
end

local function recordScore(scoreData, encoded, source)
    local updatedAt = GetServerTime()

    if source == "group" or source == "local" then
        addon.partyLeaderboardStore:Record(scoreData, encoded, updatedAt)
    end

    addon.publicLeaderboardStore:Record(scoreData, encoded, updatedAt)
end

local function queuePublicStore()
    for _, encoded in ipairs(
        addon.publicLeaderboardStore:GetEncodedPackets()
    ) do
        addon.communication:QueuePublicPacket(encoded)
    end
end

local function createLocalScorePacket()
    local scoreData = addon.scoreSession:CreateScoreData(
        getPlayerName(),
        UnitGUID("player"),
        addon.controller.score,
        addon.controller:GetLevel()
    )
    local encoded = addon.ScorePacket.Encode(scoreData)
    if encoded then
        recordScore(scoreData, encoded, "local")
    end

    return encoded
end

local function broadcastScore()
    if not addon.communication or not addon.controller then
        return false
    end

    local encoded = createLocalScorePacket()
    if not encoded then
        return false
    end

    local groupSent = addon.communication:BroadcastEncodedScore(encoded)
    if addon.publicLeaderboard.state == "CONNECTED" then
        addon.communication:QueuePublicPacket(encoded)
    end

    if addon.UI.frame then
        addon.UI:RefreshLeaderboard()
    end

    return groupSent
end


addon.BroadcastScore = broadcastScore

local function hidePublicChannelMessage(_, _, ...)
    local channelBaseName = select(9, ...)

    return channelBaseName == "GemBlast"
end

local function registerPublicChannelFilters()
    for _, event in ipairs({
        "CHAT_MSG_CHANNEL_NOTICE",
        "CHAT_MSG_CHANNEL_NOTICE_USER",
        "CHAT_MSG_CHANNEL_JOIN",
        "CHAT_MSG_CHANNEL_LEAVE",
    }) do
        ChatFrame_AddMessageEventFilter(event, hidePublicChannelMessage)
    end
end

local function movePublicChannelToLast(channelId)
    if not C_ChatInfo.SwapChatChannelsByChannelIndex then
        return
    end

    local channelList = { GetChannelList() }
    local channelIds = {}
    for index = 1, #channelList, 3 do
        channelIds[#channelIds + 1] = channelList[index]
    end

    addon.ChannelOrder.MoveToLast(
        channelId,
        channelIds,
        C_ChatInfo.SwapChatChannelsByChannelIndex
    )
end

local function handlePublicConnection(finalCheck)
    if not addon.publicLeaderboard then
        return
    end

    local newlyConnected = addon.publicLeaderboard:RefreshConnection(finalCheck)
    if newlyConnected then
        movePublicChannelToLast(addon.publicLeaderboard.channelId)
        broadcastScore()
        queuePublicStore()
        addon.communication:BroadcastPublicRequest(
            addon.publicLeaderboard.channelId
        )
    end

    addon.UI:RefreshLeaderboard()
end

local function schedulePublicConnectionCheck()
    C_Timer.After(2, function()
        handlePublicConnection(true)
    end)
end

local function joinPublicLeaderboard()
    local started = addon.publicLeaderboard:Join()
    addon.UI:RefreshLeaderboard()

    if started then
        schedulePublicConnectionCheck()
    end
end

addon.JoinPublicLeaderboard = joinPublicLeaderboard

local function handleAutoToggle(event)
    if not addon.autoToggle or not addon.UI.frame then
        return
    end

    local action
    if event == "PLAYER_REGEN_DISABLED" then
        action = addon.autoToggle:HandleCombat(
            GemBlastDB.closeInCombatEnabled,
            addon.UI.frame:IsShown()
        )
    else
        action = addon.autoToggle:Handle(
            event,
            GemBlastDB.autoToggleEnabled,
            UnitOnTaxi("player"),
            addon.UI.frame:IsShown()
        )
    end

    if action == "show" then
        addon.UI.frame:Show()
        addon.UI.menu:Hide()
        addon.UI:Refresh()
    elseif action == "hide" then
        addon.UI.frame:Hide()
    end
end

local function scheduleTaxiChecks()
    for _, delay in ipairs({ 0.2, 0.75 }) do
        C_Timer.After(delay, function()
            handleAutoToggle("TAXI_STATE_CHECK")
        end)
    end
end

addon.HandleAutoToggle = handleAutoToggle

local function restoreWindow()
    local window = GemBlastDB.window

    addon.UI.frame:ClearAllPoints()
    addon.UI.frame:SetPoint(window.point, UIParent, window.point, window.x, window.y)
    addon.UI.frame:SetScale(window.scale)
end

local function initialize()
    local savedData = addon.Persistence.SelectSavedData(
        GemBlastDB,
        BetterBejeweledDB
    )

    GemBlastDB = addon.Persistence.Normalize(savedData)
    BetterBejeweledDB = nil
    addon.scoreSession = addon.ScoreSession.New(GemBlastDB, {
        generateId = generateId,
    })
    addon.partyLeaderboardStore = addon.LeaderboardStore.New(
        GemBlastDB.partyTopScores,
        10
    )
    addon.publicLeaderboardStore = addon.LeaderboardStore.New(
        GemBlastDB.publicTopScores,
        10
    )
    addon.controller = addon.Controller.New(GemBlastDB)
    addon.autoToggle = addon.AutoToggle.New()
    addon.publicLeaderboard = addon.PublicLeaderboard.New({
        joinChannel = function(channelName)
            return JoinTemporaryChannel(channelName)
        end,
        leaveChannel = function(channelName)
            LeaveChannelByName(channelName)
        end,
        getChannelId = function(channelName)
            return GetChannelName(channelName)
        end,
        hideChannel = function(channelName)
            for _, chatFrameName in ipairs(CHAT_FRAMES or {}) do
                local chatFrame = _G[chatFrameName]
                if chatFrame then
                    ChatFrame_RemoveChannel(chatFrame, channelName)
                end
            end
        end,
    }, publicLeaderboardAvailable)
    if not publicLeaderboardAvailable then
        GemBlastDB.publicLeaderboardEnabled = false
        GemBlastDB.leaderboardMode = "party"
    end

    addon.communication = addon.Communication.New({
        registerPrefix = C_ChatInfo.RegisterAddonMessagePrefix,
        send = C_ChatInfo.SendAddonMessage,
        isInGroup = function()
            return IsInGroup()
        end,
        isInRaid = function()
            return IsInRaid()
        end,
        isInInstanceGroup = function()
            return IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
        end,
        playerName = function()
            return getPlayerName()
        end,
        now = function()
            return GetTime()
        end,
        isPublicChannel = function(target)
            return addon.publicLeaderboard:IsChannelTarget(target)
        end,
        decodeScore = addon.ScorePacket.Decode,
        accountId = addon.scoreSession.accountId,
    })
    addon.communication:Register()
    registerPublicChannelFilters()
    addon.UI:Create()
    restoreWindow()
    addon.Launcher:Create()

    events:RegisterEvent("CHAT_MSG_ADDON")
    events:RegisterEvent("CHANNEL_UI_UPDATE")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_CONTROL_GAINED")
    events:RegisterEvent("PLAYER_CONTROL_LOST")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("TAXIMAP_CLOSED")
    events:RegisterEvent("UNIT_FLAGS")

    C_Timer.NewTicker(1, function()
        if addon.publicLeaderboard.state == "CONNECTED" then
            addon.communication:FlushPublicQueue(
                addon.publicLeaderboard.channelId
            )
        end
    end)

    C_Timer.NewTicker(SCORE_SYNC_INTERVAL, function()
        local hasGroupChannel = addon.communication:GetGroupChannel() ~= nil
        local hasPublicChannel =
            addon.publicLeaderboard.state == "CONNECTED"

        if hasGroupChannel or hasPublicChannel then
            broadcastScore()
        end
    end)
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event, ...)
    local firstArgument = ...

    if event == "ADDON_LOADED" and firstArgument == addonName then
        initialize()
        return
    end

    if event == "CHAT_MSG_ADDON" and addon.communication then
        local accepted, messageType, scoreData, source, encoded =
            addon.communication:HandleMessage(...)
        if accepted and messageType == "request" then
            queuePublicStore()
        elseif accepted and scoreData then
            recordScore(scoreData, encoded, source)

            if source == "group"
                and addon.publicLeaderboard.state == "CONNECTED" then
                addon.communication:QueuePublicPacket(encoded)
            end
        end

        if accepted and addon.UI.frame then
            addon.UI:RefreshLeaderboard()
        end
        return
    end

    if event == "CHANNEL_UI_UPDATE" then
        handlePublicConnection()
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        addon.communication:ClearPeerScores()
        addon.UI:RefreshLeaderboard()
        broadcastScore()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        if GemBlastDB.publicLeaderboardEnabled
            and not addon.publicLeaderboard.enabled then
            joinPublicLeaderboard()
        end

        broadcastScore()
        handleAutoToggle(event)
        return
    end

    if event == "PLAYER_CONTROL_GAINED"
        or event == "PLAYER_CONTROL_LOST"
        or event == "PLAYER_REGEN_DISABLED" then
        handleAutoToggle(event)

        if event == "PLAYER_CONTROL_LOST" then
            scheduleTaxiChecks()
        end

        return
    end

    if event == "TAXIMAP_CLOSED" then
        scheduleTaxiChecks()
        return
    end

    if event == "UNIT_FLAGS" and firstArgument == "player" then
        handleAutoToggle(event)
        return
    end

    if event == "PLAYER_LOGOUT" and addon.UI.frame then
        addon.UI:Save()
    end
end)
