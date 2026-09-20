local ChannelOrder = {}
local _, addon = ...

function ChannelOrder.MoveToLast(channelId, channelIds, swapChannels)
    local laterChannelIds = {}
    local targetFound = false

    for _, joinedChannelId in ipairs(channelIds) do
        if joinedChannelId == channelId then
            targetFound = true
        elseif joinedChannelId > channelId then
            laterChannelIds[#laterChannelIds + 1] = joinedChannelId
        end
    end

    if not targetFound then
        return
    end

    table.sort(laterChannelIds)

    local currentChannelId = channelId
    for _, nextChannelId in ipairs(laterChannelIds) do
        swapChannels(currentChannelId, nextChannelId)
        currentChannelId = nextChannelId
    end
end

if type(addon) == "table" then
    addon.ChannelOrder = ChannelOrder
end

return ChannelOrder
