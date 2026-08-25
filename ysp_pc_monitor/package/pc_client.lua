local PcClient = {}
PcClient.__index = PcClient

local function now_ms()
  if type(millis) == "function" then
    local ok, value = pcall(millis)
    if ok and type(value) == "number" then return value end
  end
  if tmr and type(tmr.now) == "function" then
    local ok, value = pcall(tmr.now)
    if ok and type(value) == "number" then return math.floor(value / 1000) end
  end
  return 0
end

local function trim(value)
  if value == nil then return "" end
  return (tostring(value):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function first_number(value)
  local number = tostring(value or ""):match("([%-+]?%d+%.?%d*)")
  return number and tonumber(number) or nil
end

local function split_remote_items(payload)
  local items = {}
  local pos = 1
  payload = tostring(payload or "")
  while pos <= #payload do
    local first, last = payload:find("%{%|%}", pos)
    if not first then
      items[#items + 1] = payload:sub(pos)
      break
    end
    items[#items + 1] = payload:sub(pos, first - 1)
    pos = last + 1
  end
  return items
end

local function strip_label(text, label)
  text = trim(text)
  label = trim(label)
  if label == "" then return text end
  local lower = text:lower()
  local needle = label:lower()
  if lower:sub(1, #needle) == needle then
    return trim(text:sub(#needle + 1):gsub("^[%s:=%-]+", ""))
  end
  return text
end

local function assign(snapshot, path, value)
  local head, tail = path:match("^([^.]+)%.(.+)$")
  if not head or not tail then return end
  snapshot[head] = snapshot[head] or {}
  snapshot[head][tail] = value
end

local numeric_fields = {
  CPU_USAGE = "cpu.load",
  CPU_TEMP = "cpu.temp",
  CPU_DIODE = "cpu.temp",
  CPU_CCD_TEMP = "cpu.ccd_temp",
  CPU_CLOCK = "cpu.clock",
  CPU_FREQ = "cpu.clock",
  CPU_POWER = "cpu.power",
  GPU_USAGE = "gpu.load",
  GPU_TEMP = "gpu.temp",
  GPU_MEMORY_TEMP = "gpu.memory_temp",
  GPU_CLOCK = "gpu.clock",
  GPU_CORE_CLOCK = "gpu.clock",
  GPU_POWER = "gpu.power",
  GPU_FAN = "gpu.fan_rpm",
  SSD_TEMP = "storage.ssd_temp",
  MEM_DIMM1_TEMP = "memory.dimm1_temp",
  MEM_DIMM3_TEMP = "memory.dimm3_temp",
  BOARD_FAN1 = "fans.board1_rpm",
  BOARD_FAN2 = "fans.board2_rpm",
  BOARD_FAN3 = "fans.board3_rpm",
  BOARD_FAN4 = "fans.board4_rpm",
  MEM_USAGE = "memory.load",
  MEM_USED = "memory.used_gb",
  MEM_AVAILABLE = "memory.free_gb",
  NET_UPLOAD = "network.up",
  NET_DOWNLOAD = "network.down",
}

local text_fields = {
  CPU_NAME = { path = "cpu.name", label = "CPU Name" },
  GPU_NAME = { path = "gpu.name", label = "GPU Name" },
}

local numeric_labels = {
  CPU_CCD_TEMP = "CPU CCD",
  GPU_MEMORY_TEMP = "GPU Memory Junction",
  SSD_TEMP = "SSD Composite",
  MEM_DIMM1_TEMP = "DIMM #1",
  MEM_DIMM3_TEMP = "DIMM #3",
  BOARD_FAN1 = "Board Fan #1",
  BOARD_FAN2 = "Board Fan #2",
  BOARD_FAN3 = "Board Fan #3",
  BOARD_FAN4 = "Board Fan #4",
}

local label_fallback = {
  ["CPU Usage"] = "cpu.load",
  ["CPU Temperature"] = "cpu.temp",
  ["CPU Diode"] = "cpu.temp",
  ["CPU CCD"] = "cpu.ccd_temp",
  ["CPU Clock"] = "cpu.clock",
  ["CPU Frequency"] = "cpu.clock",
  ["CPU Package Power"] = "cpu.power",
  ["GPU Usage"] = "gpu.load",
  ["GPU Temperature"] = "gpu.temp",
  ["GPU Memory Junction"] = "gpu.memory_temp",
  ["GPU Clock"] = "gpu.clock",
  ["GPU Core Clock"] = "gpu.clock",
  ["GPU Power"] = "gpu.power",
  ["GPU Fan"] = "gpu.fan_rpm",
  ["SSD Composite"] = "storage.ssd_temp",
  ["DIMM #1"] = "memory.dimm1_temp",
  ["DIMM #3"] = "memory.dimm3_temp",
  ["Board Fan #1"] = "fans.board1_rpm",
  ["Board Fan #2"] = "fans.board2_rpm",
  ["Board Fan #3"] = "fans.board3_rpm",
  ["Board Fan #4"] = "fans.board4_rpm",
  ["Memory Usage"] = "memory.load",
  ["Memory Used"] = "memory.used_gb",
  ["Memory Available"] = "memory.free_gb",
  ["Upload Speed"] = "network.up",
  ["Download Speed"] = "network.down",
}

local function parse_payload(payload)
  local snapshot = {
    cpu = {},
    gpu = {},
    memory = {},
    network = {},
    raw = {},
    valid = false,
  }
  local numeric_count = 0

  for _, item in ipairs(split_remote_items(payload)) do
    local key, text = tostring(item):match("^([^|]+)|(.+)$")
    if key and text then
      key = trim(key):upper()
      text = trim(text)
      snapshot.raw[key] = text

      local text_def = text_fields[key]
      if text_def then
        assign(snapshot, text_def.path, strip_label(text, text_def.label))
      else
        local path = numeric_fields[key]
        local value = first_number(numeric_labels[key] and strip_label(text, numeric_labels[key]) or text)
        if not path then
          for label, fallback_path in pairs(label_fallback) do
            if text:lower():find(label:lower(), 1, true) then
              path = fallback_path
              value = first_number(strip_label(text, label))
              break
            end
          end
        end
        if path and value ~= nil then
          assign(snapshot, path, value)
          numeric_count = numeric_count + 1
        end
      end
    end
  end

  snapshot.valid = numeric_count > 0
  return snapshot
end

local function callback_string_arg(...)
  for i = 1, select("#", ...) do
    local value = select(i, ...)
    if type(value) == "string" then return value end
  end
  return nil
end

function PcClient.new(config, handlers)
  local self = setmetatable({}, PcClient)
  self.config = config or {}
  self.handlers = handlers or {}
  self.buffer = ""
  self.connection = nil
  self.reconnect_timer = nil
  self.watchdog_timer = nil
  self.closed = false
  self.last_event_ms = 0
  self.connect_started_ms = 0
  self.reconnect_delay_ms = tonumber(self.config.reconnect_ms) or 2000
  return self
end

function PcClient:reset_reconnect_delay()
  self.reconnect_delay_ms = tonumber(self.config.reconnect_ms) or 2000
end

function PcClient:path()
  local path = tostring(self.config.path or "/sse")
  if path:sub(1, 1) ~= "/" then path = "/" .. path end
  return path
end

function PcClient:url()
  return "http://" .. tostring(self.config.host) .. ":" .. tostring(self.config.port or 28765) .. self:path()
end

function PcClient:emit_status(status, detail)
  if self.handlers.on_status then
    pcall(self.handlers.on_status, status, detail or "")
  end
end

function PcClient:emit_sample(payload)
  local snapshot = parse_payload(payload)
  if snapshot.valid then
    self.last_event_ms = now_ms()
    self:reset_reconnect_delay()
    if self.handlers.on_sample then
      pcall(self.handlers.on_sample, snapshot, payload)
    end
  end
end

function PcClient:handle_line(line)
  local payload = tostring(line or ""):match("^data:%s*(.*)$")
  if payload and payload ~= "" then
    self:emit_sample(payload)
  end
end

function PcClient:handle_chunk(chunk)
  self.buffer = self.buffer .. tostring(chunk or "")
  while true do
    local first, last = self.buffer:find("\n", 1, true)
    if not first then break end
    local line = self.buffer:sub(1, first - 1):gsub("\r$", "")
    self.buffer = self.buffer:sub(last + 1)
    self:handle_line(line)
  end
  if #self.buffer > 8192 then
    self.buffer = self.buffer:sub(-2048)
  end
end

function PcClient:close_connection()
  if self.connection then
    pcall(function() self.connection:close() end)
  end
  self.connection = nil
end

function PcClient:schedule_reconnect()
  if self.closed then return end
  if not tmr or not tmr.create then return end
  if self.reconnect_timer then pcall(function() self.reconnect_timer:unregister() end) end
  local base_delay = math.max(1000, math.floor(tonumber(self.config.reconnect_ms) or 2000))
  local max_delay = math.max(base_delay, math.floor(tonumber(self.config.reconnect_max_ms) or base_delay))
  local delay = math.max(base_delay, math.min(max_delay, math.floor(tonumber(self.reconnect_delay_ms) or base_delay)))
  self.reconnect_timer = tmr.create()
  self.reconnect_timer:alarm(delay, tmr.ALARM_SINGLE, function()
    self:connect()
  end)
  self.reconnect_delay_ms = math.min(max_delay, delay * 2)
end

function PcClient:connect()
  if self.closed then return end
  self:close_connection()
  self.buffer = ""
  self.connect_started_ms = now_ms()
  self:emit_status("connecting", self:url())

  if not net or not net.createConnection then
    self:emit_status("error", "net unavailable")
    self:schedule_reconnect()
    return
  end

  local ok, conn_or_err = pcall(function()
    if net.TCP then return net.createConnection(net.TCP, false) end
    return net.createConnection()
  end)
  if not ok or not conn_or_err then
    self:emit_status("error", tostring(conn_or_err))
    self:schedule_reconnect()
    return
  end

  local conn = conn_or_err
  self.connection = conn

  local function bind(event, callback)
    local bind_ok = pcall(function() conn:on(event, callback) end)
    if not bind_ok then
      self:emit_status("error", "bind " .. event)
      self:schedule_reconnect()
      return false
    end
    return true
  end

  if not bind("connection", function()
    self.connect_started_ms = 0
    self:reset_reconnect_delay()
    self:emit_status("connected", self:url())
    local request = table.concat({
      "GET " .. self:path() .. " HTTP/1.1",
      "Host: " .. tostring(self.config.host) .. ":" .. tostring(self.config.port or 28765),
      "Accept: text/event-stream",
      "Cache-Control: no-cache",
      "Connection: keep-alive",
      "",
      "",
    }, "\r\n")
    pcall(function() conn:send(request) end)
  end) then return end

  if not bind("receive", function(...)
    local chunk = callback_string_arg(...)
    if chunk and #chunk > 0 then
      local data_ok, data_err = pcall(function() self:handle_chunk(chunk) end)
      if not data_ok then
        self:emit_status("error", "data " .. tostring(data_err))
        self:close_connection()
        self:schedule_reconnect()
      end
    end
  end) then return end

  if not bind("disconnection", function(...)
    if self.closed then return end
    self.connect_started_ms = 0
    self:emit_status("disconnected", callback_string_arg(...) or "")
    self:schedule_reconnect()
  end) then return end

  local connect_ok, connect_err = pcall(function()
    conn:connect(self.config.port or 28765, self.config.host)
  end)
  if not connect_ok then
    self.connect_started_ms = 0
    self:emit_status("error", tostring(connect_err))
    self:schedule_reconnect()
  end
end

function PcClient:start_watchdog()
  if not tmr or not tmr.create then return end
  if self.watchdog_timer then pcall(function() self.watchdog_timer:unregister() end) end
  self.watchdog_timer = tmr.create()
  self.watchdog_timer:alarm(self.config.watchdog_ms or 1000, tmr.ALARM_AUTO, function()
    if self.closed then return end
    local now = now_ms()
    if self.connect_started_ms > 0 and now - self.connect_started_ms > (self.config.timeout_ms or 7000) then
      self.connect_started_ms = 0
      self:emit_status("timeout", "connect")
      self:close_connection()
      self:schedule_reconnect()
      return
    end
    if self.last_event_ms > 0 and now - self.last_event_ms > (self.config.client_stale_ms or 5000) then
      self.last_event_ms = 0
      self:emit_status("stale", "no sse data")
      self:close_connection()
      self:schedule_reconnect()
    end
  end)
end

function PcClient:start()
  self.closed = false
  self:reset_reconnect_delay()
  self:start_watchdog()
  self:connect()
end

function PcClient:stop()
  self.closed = true
  if self.reconnect_timer then pcall(function() self.reconnect_timer:unregister() end) end
  self.reconnect_timer = nil
  if self.watchdog_timer then pcall(function() self.watchdog_timer:unregister() end) end
  self.watchdog_timer = nil
  self:close_connection()
end

PcClient.parse_payload = parse_payload

return PcClient
