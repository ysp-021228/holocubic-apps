local Pager = {}
Pager.__index = Pager

local function clamp_page(page, count)
  count = math.max(1, math.floor(tonumber(count) or 1))
  page = math.floor(tonumber(page) or 1)
  if page < 1 then return 1 end
  if page > count then return count end
  return page
end

function Pager.new(config)
  config = config or {}
  local cooldown = tonumber(config.tilt_page_cooldown_ms) or 1000
  return setmetatable({
    config = config,
    page = 1,
    last_switch_ms = -cooldown,
  }, Pager)
end

function Pager:cooldown_ms()
  return math.max(250, math.floor(tonumber(self.config.tilt_page_cooldown_ms) or 1000))
end

function Pager:set_page(page, page_count)
  self.page = clamp_page(page, page_count)
  return self.page
end

function Pager:step(direction, page_count, now_ms)
  page_count = math.max(1, math.floor(tonumber(page_count) or 1))
  if page_count < 2 then
    self.page = clamp_page(self.page, page_count)
    return self.page, false
  end

  now_ms = math.floor(tonumber(now_ms) or 0)
  if now_ms - self.last_switch_ms < self:cooldown_ms() then
    return clamp_page(self.page, page_count), false
  end

  direction = tonumber(direction) or 0
  if direction == 0 then
    self.page = clamp_page(self.page, page_count)
    return self.page, false
  end

  self.page = ((clamp_page(self.page, page_count) - 1 + (direction < 0 and -1 or 1)) % page_count) + 1
  self.last_switch_ms = now_ms
  return self.page, true
end

return Pager
