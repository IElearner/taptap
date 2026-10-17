local Data = require "game.SaveData"
---@class VillageSaveStore
---@field backend table
---@field now fun():number
---@field revisions table<string,number>
---@field lastTimes table<string,number>
---@field cloudReady table<string,boolean>
---@field pendingWrites table<string,table>
---@field queuedWrites table<string,table>
---@field generation number
---@field loadElapsed number
---@field loading boolean
---@field activeMode string
---@field status string
---@field completeLoad false|function
local Store = {}
Store.__index = Store
local function engineBackend()
    local function read(name)
        if not fileSystem:FileExists(name) then return nil end
        local f = File(name, FILE_READ)
        if not f:IsOpen() then return nil end
        local value = f:ReadString(); f:Close(); return value
    end
    local function write(name, value)
        local f = File(name, FILE_WRITE)
        if not f:IsOpen() then return false end
        local ok = f:WriteString(value); f:Flush(); f:Close(); return ok
    end
    local function cloudAvailable() return clientCloud ~= nil and clientCloud.userId > 0 end
    return {
        now = os.time, read = read, write = write,
        cloudGet = function(key, callback)
            if not cloudAvailable() then return false end
            clientCloud:Get(key, {
                ok = function(values) callback(true, values and values[key]) end,
                error = function() callback(false) end, timeout = function() callback(false) end,
            })
            return true
        end,
        cloudSet = function(key, value, callback)
            if not cloudAvailable() then return false end
            clientCloud:Set(key, value, {
                ok = function() callback(true) end,
                error = function() callback(false) end, timeout = function() callback(false) end,
            })
            return true
        end,
    }
end
local function filename(mode) return "shanheli_save_v1_" .. mode .. ".json" end
Store.nativeBackend = engineBackend
local function cloudKey(mode) return "shanheli_save_v1_" .. mode end
function Store.new(backend)
    local self = setmetatable({}, Store)
    self:init(backend or engineBackend())
    return self
end
function Store:init(backend)
    self.backend = backend
    self.now = backend.now or os.time
    self.revisions, self.lastTimes, self.cloudReady, self.pendingWrites, self.queuedWrites = {}, {}, {}, {}, {}
    self.generation, self.loadElapsed = 0, 0
    self.loading, self.activeMode, self.status = false, "finite", "尚未存档"
    self.completeLoad = false
end
function Store:decode(value, mode)
    if value == nil or value == false then return nil end
    local decoded = value
    if type(value) == "string" then
        if #value > 4 * 1024 * 1024 then return nil end
        local ok, result = pcall(cjson.decode, value)
        if not ok then return nil end
        decoded = result
    end
    if Data.restore(decoded, mode) then return decoded end
    return nil
end
local function newer(a, b)
    if not a then return b end
    if not b then return a end
    if b.savedAt > a.savedAt or (b.savedAt == a.savedAt and b.revision > a.revision) then return b end
    return a
end
function Store:load(mode, callback)
    self.generation, self.loading, self.loadElapsed, self.activeMode = self.generation + 1, true, 0, mode
    self.status, self.cloudReady[mode] = "读取存档中…", false
    local generation = self.generation
    local localData = newer(self:decode(self.backend.read(filename(mode)), mode), self:decode(self.backend.read(filename(mode) .. ".bak"), mode))
    local finished = false
    local function finish(cloudOk, value, available)
        if finished or generation ~= self.generation then return end
        finished, self.loading, self.completeLoad = true, false, false
        self.cloudReady[mode] = cloudOk
        local cloudData = cloudOk and self:decode(value, mode) or nil
        -- Invalid remote data is not silently overwritten by a new empty game.
        if cloudOk and value ~= nil and value ~= false and not cloudData then self.cloudReady[mode] = false end
        local best = newer(localData, cloudData)
        if best then
            self.revisions[mode], self.lastTimes[mode] = best.revision, best.savedAt
            self.status = best == cloudData and "已读取云存档" or "已读取本地存档"
        else self.status = "此模式暂无存档" end
        if available and not self.cloudReady[mode] then self.status = self.status .. " · 云端未读，仅存本地" end
        callback(best)
    end
    self.completeLoad = function() finish(false, nil, true) end
    if not self.backend.cloudGet then finish(false, nil, false); return end
    local ok, sent = pcall(self.backend.cloudGet, cloudKey(mode), function(success, data) finish(success, data, true) end)
    if not ok or not sent then finish(false, nil, false) end
end
function Store:flush(mode)
    if self.pendingWrites[mode] or not self.queuedWrites[mode] then return end
    local queued = self.queuedWrites[mode]
    self.queuedWrites[mode] = nil
    local pending = { elapsed = 0, revision = queued.revision }
    self.pendingWrites[mode] = pending
    local finished = false
    local function done(ok)
        if finished or self.pendingWrites[mode] ~= pending then return end
        finished, self.pendingWrites[mode] = true, nil
        if self.activeMode == mode and self.revisions[mode] == queued.revision then
            if ok then self.status = queued.localWritten and "云端与本地已保存" or "云端已保存 · 本地不可写"
            else self.status = queued.localWritten and "云端保存失败 · 本地副本已保留" or "保存失败，请保留当前游戏" end
        end
        self:flush(mode)
    end
    local ok, sent = pcall(self.backend.cloudSet, cloudKey(mode), queued.blob, done)
    if not ok or not sent then done(false) end
end
function Store:save(sim, idleEnabled)
    local mode = sim.mode
    if self.loading then return false end
    local revision = (self.revisions[mode] or 0) + 1
    local at = math.max(self.now(), self.lastTimes[mode] or 0)
    local bundle = Data.capture(sim, at, revision, idleEnabled)
    local blob = cjson.encode(bundle)
    if #blob > 4 * 1024 * 1024 then self.status = "存档超出大小限制，未覆盖旧档"; return false end
    local previous = self.backend.read(filename(mode))
    if self:decode(previous, mode) then self.backend.write(filename(mode) .. ".bak", previous) end
    local ok = self.backend.write(filename(mode), blob)
    self.revisions[mode], self.lastTimes[mode] = revision, at
    if self.activeMode == mode then self.status = ok and "本地已保存" or "本地保存失败" end
    if self.cloudReady[mode] and self.backend.cloudSet then
        self.queuedWrites[mode] = { blob = blob, revision = revision, localWritten = ok }
        if self.activeMode == mode then self.status = ok and "本地已存 · 正在同步云端…" or "本地不可写 · 正在同步云端…" end
        self:flush(mode)
    end
    return ok
end
function Store:update(dt)
    if self.loading then
        self.loadElapsed = self.loadElapsed + dt
        if self.loadElapsed >= 8 and self.completeLoad then self.completeLoad() end
    end
    for mode, pending in pairs(self.pendingWrites) do
        pending.elapsed = pending.elapsed + dt
        if pending.elapsed >= 20 then
            self.pendingWrites[mode] = nil
            if self.activeMode == mode then self.status = "云同步超时 · 本地副本已保留" end
            self:flush(mode)
        end
    end
end
return Store
