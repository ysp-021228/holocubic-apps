local Printer = {}
Printer.__index = Printer

function Printer.new(config, now_ms, on_update)
  return setmetatable({
    url = string.format("http://%s:%s/printer/status", config.host, config.port or 28765),
    now_ms = now_ms,
    on_update = on_update,
    next_ms = 0,
    request_id = 0,
  }, Printer)
end

function Printer:poll(force)
  if self.stopped or not (http and http.get and sjson and sjson.decode) then return end
  local now = self.now_ms()
  if self.deadline_ms and now < self.deadline_ms then return end
  if not force and now < self.next_ms then return end
  self.next_ms = now + 3000
  self.deadline_ms = now + 5000
  self.request_id = self.request_id + 1
  local id = self.request_id
  local function completed(code, body)
    if self.stopped or id ~= self.request_id then return end
    self.deadline_ms = nil
    if code ~= 200 or type(body) ~= "string" or #body > 2048 then return end
    local ok, value = pcall(sjson.decode, body)
    if not ok or type(value) ~= "table" then return end
    local sample = value.sample
    if (value.state == "live" or value.state == "stale") and type(sample) == "table" and
        type(sample.phase) == "string" and #sample.phase <= 24 and sample.phase:match("^[A-Z ]+$") then
      self.sample = sample
      self.last_live_ms = value.state == "live" and self.now_ms() or nil
    elseif value.state == "no_data" then
      self.last_live_ms = nil
    else
      return
    end
    self.on_update()
  end
  local ok, result = pcall(http.get, self.url, { timeout = 3500, max_redirects = 0 }, completed)
  if not ok or result == false then self.deadline_ms = nil end
end

function Printer:is_stale()
  return self.sample ~= nil and (not self.last_live_ms or self.now_ms() - self.last_live_ms >= 8000)
end

function Printer:stop()
  self.stopped = true
end

return Printer
