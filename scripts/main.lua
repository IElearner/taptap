-- Maker entrypoint. Gameplay remains in the single-player module.
local Game = require "network.Standalone"
function Start()
    Game.Start()
    SubscribeToEvent("Update", "HandleVillageUpdate")
end
---@param eventType string
---@param eventData UpdateEventData
function HandleVillageUpdate(eventType, eventData)
    Game.Update(eventData:GetFloat("TimeStep"))
end
function Stop() Game.Stop() end
