local PcState = {}
PcState.__index = PcState

local function branch()
  return {}
end

local function empty_snapshot(power_history, load_history)
  return {
    cpu = branch(),
    gpu = branch(),
    storage = branch(),
    fans = branch(),
    memory = branch(),
    network = branch(),
    power_history = power_history or {},
    load_history = load_history or { cpu = {}, gpu = {}, memory = {} },
    raw = {},
    valid = false,
    received_at = 0,
  }
end

local function total_power(snapshot)
  local cpu, gpu = snapshot.cpu or {}, snapshot.gpu or {}
  local cpu_power = tonumber(cpu.power)
  local gpu_power = tonumber(gpu.power)
  if cpu_power == nil and gpu_power == nil then return nil end
  return (cpu_power or 0) + (gpu_power or 0)
end

local function remember_power_sample(state, snapshot)
  state.power_history = state.power_history or {}

  local value = total_power(snapshot)
  if value then
    local max_samples = math.max(2, math.floor(tonumber(state.config.power_history_samples) or 40))
    state.power_history[#state.power_history + 1] = value
    while #state.power_history > max_samples do
      table.remove(state.power_history, 1)
    end
  end

  snapshot.power_history = state.power_history
end

local function push_sample(history, value, max_samples)
  value = tonumber(value)
  if not value then return end

  history[#history + 1] = math.max(0, math.min(100, value))
  while #history > max_samples do
    table.remove(history, 1)
  end
end

local function remember_load_sample(state, snapshot)
  state.load_history = state.load_history or { cpu = {}, gpu = {}, memory = {} }

  local max_samples = math.max(2, math.floor(tonumber(state.config.load_history_samples) or 40))
  push_sample(state.load_history.cpu, snapshot.cpu and snapshot.cpu.load, max_samples)
  push_sample(state.load_history.gpu, snapshot.gpu and snapshot.gpu.load, max_samples)
  push_sample(state.load_history.memory, snapshot.memory and snapshot.memory.load, max_samples)

  snapshot.load_history = state.load_history
end

function PcState.new(config)
  local power_history = {}
  local load_history = { cpu = {}, gpu = {}, memory = {} }
  return setmetatable({
    config = config or {},
    online = false,
    status = "STARTING",
    detail = "",
    valid_frames = 0,
    last_valid_ms = 0,
    last_transition_ms = 0,
    power_history = power_history,
    load_history = load_history,
    snapshot = empty_snapshot(power_history, load_history),
  }, PcState)
end

function PcState:set_status(status, detail)
  self.status = tostring(status or self.status or "")
  self.detail = tostring(detail or "")
end

function PcState:apply_sample(snapshot, now_ms)
  if type(snapshot) ~= "table" or not snapshot.valid then
    return nil
  end

  now_ms = math.floor(tonumber(now_ms) or 0)
  snapshot.received_at = now_ms
  remember_power_sample(self, snapshot)
  remember_load_sample(self, snapshot)
  self.snapshot = snapshot
  self.last_valid_ms = now_ms
  self.status = "LIVE"
  self.detail = ""

  if self.online then
    self.valid_frames = math.min(tonumber(self.config.online_after_frames) or 2, self.valid_frames + 1)
    return nil
  end

  self.valid_frames = self.valid_frames + 1
  if self.valid_frames >= (tonumber(self.config.online_after_frames) or 2) then
    self.online = true
    self.last_transition_ms = now_ms
    return "online"
  end

  return nil
end

function PcState:update_presence(now_ms)
  now_ms = math.floor(tonumber(now_ms) or 0)
  if self.online and self.last_valid_ms > 0 then
    if now_ms - self.last_valid_ms >= (tonumber(self.config.offline_after_ms) or 10000) then
      self.online = false
      self.valid_frames = 0
      self.status = "OFFLINE"
      self.detail = "no pc data"
      self.last_transition_ms = now_ms
      return "offline"
    end
  end
  return nil
end

function PcState:reset()
  self.online = false
  self.status = "STARTING"
  self.detail = ""
  self.valid_frames = 0
  self.last_valid_ms = 0
  self.power_history = {}
  self.load_history = { cpu = {}, gpu = {}, memory = {} }
  self.snapshot = empty_snapshot(self.power_history, self.load_history)
end

PcState.empty_snapshot = empty_snapshot

return PcState
