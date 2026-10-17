-- Maker entrypoint. Gameplay remains in the single-player module.
local Game = require "network.Standalone"
function Start()
    Game.Start()
    SubscribeToEvent("Update", "HandleVillageUpdate")
    SubscribeToEvent("InputFocus", "HandleVillageFocus")
end
---@param eventType string
---@param eventData InputFocusEventData
function HandleVillageFocus(eventType, eventData)
    Game.Focus(eventData:GetBool("Focus") and not eventData:GetBool("Minimized"))
end
---@param eventType string
---@param eventData UpdateEventData
function HandleVillageUpdate(eventType, eventData)
    Game.Update(eventData:GetFloat("TimeStep"))
end
function Stop() Game.Stop() end
