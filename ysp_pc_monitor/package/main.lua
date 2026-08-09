local APP_DIR = "/sd/apps/ysp_pc_monitor"

local function exists(path)
  return file and file.exists and file.exists(path)
end

if not exists(APP_DIR .. "/pc_client.lua") then
  local candidates = {
    "ysp_pc_monitor/package",
    "/sd/apps/ysp_pc_monitor",
  }
  for _, dir in ipairs(candidates) do
    if exists(dir .. "/pc_client.lua") then
      APP_DIR = dir
      break
    end
  end
end

local previous = rawget(_G, "__ysp_pc_monitor")
if previous and previous.stop then
  pcall(function() previous.stop("reload") end)
end

local config = dofile(APP_DIR .. "/config.lua")
local PcClient = dofile(APP_DIR .. "/pc_client.lua")
local PcState = dofile(APP_DIR .. "/pc_state.lua")
local Pager = dofile(APP_DIR .. "/pager.lua")
local Draw = dofile(APP_DIR .. "/widgets/draw.lua")
local Format = dofile(APP_DIR .. "/widgets/format.lua")

local pages = {
  dofile(APP_DIR .. "/pages/system.lua"),
  dofile(APP_DIR .. "/pages/thermal.lua"),
  dofile(APP_DIR .. "/pages/power.lua"),
  dofile(APP_DIR .. "/pages/network.lua"),
}
local ambient_page = dofile(APP_DIR .. "/pages/ambient.lua")

local function bit_or(a, b)
  if bit32 and bit32.bor then return bit32.bor(a or 0, b or 0) end
  return (a or 0) + (b or 0)
end

local MAIN = bit_or(rawget(_G, "LV_PART_MAIN") or 0, rawget(_G, "LV_STATE_DEFAULT") or 0)
local CANVAS_FMT = rawget(_G, "LV_IMG_CF_TRUE_COLOR") or rawget(_G, "CANVAS_FMT_TRUE_COLOR")

local colors = {
  bg = 0x05070A,
  card = 0x111820,
  line = 0x26313D,
  muted = 0x758393,
  sub = 0xA8B3C2,
  text = 0xF4F7FB,
  cpu = 0x43C8FF,
  gpu = 0x62E493,
  mem = 0xF3BE4D,
  net = 0x58A6FF,
  warn = 0xFF9F43,
  ok = 0x62E493,
  accent = 0xE7C21D,
}

local state = {
  stopped = false,
  canvas = nil,
  client = nil,
  tick_timer = nil,
  runtime = PcState.new(config),
  pager = Pager.new(config),
  hud_title = "",
  hud_until_ms = 0,
}

local function log(...)
  if config.serial_log ~= false and print then
    print("[ysp-pc-monitor]", ...)
  end
end

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

local function clock_text()
  if time and time.getlocal then
    local ok, value = pcall(time.getlocal)
    if ok and type(value) == "table" then
      local hour = tonumber(value.hour or value[4]) or 0
      local min = tonumber(value.min or value.minute or value[5]) or 0
      return string.format("%02d:%02d", hour, min)
    end
  end
  if os and os.date then
    return os.date("%H:%M")
  end
  return "--:--"
end

local function show_hud(title)
  state.hud_title = tostring(title or "")
  state.hud_until_ms = now_ms() + 1200
end

local function active_page()
  if not state.runtime.online then
    return ambient_page
  end
  return pages[state.pager:set_page(state.pager.page, #pages)] or pages[1]
end

local function render()
  if state.stopped or not state.canvas then return end

  local explicit = Draw.begin(state.canvas)
  Draw.fill(state.canvas, colors.bg)

  local page = active_page()
  local now = now_ms()
  local footer_text
  if state.runtime.online then
    if state.hud_title ~= "" and now < state.hud_until_ms then
      footer_text = state.hud_title .. "  " .. tostring(state.pager.page) .. "/" .. tostring(#pages)
    else
      footer_text = tostring(state.pager.page) .. "/" .. tostring(#pages)
    end
  else
    footer_text = "AMBIENT"
  end

  local ctx = {
    canvas = state.canvas,
    draw = Draw,
    format = Format,
    colors = colors,
    config = config,
    runtime = state.runtime,
    online = state.runtime.online,
    clock = clock_text(),
    page = state.pager.page,
    page_count = #pages,
  }

  page.render(ctx, state.runtime.snapshot)
  Draw.footer(ctx, footer_text)
  Draw.finish(state.canvas, explicit)
end

local function set_online_page(page)
  state.pager:set_page(page, #pages)
  show_hud((pages[state.pager.page] and pages[state.pager.page].title) or "")
end

local function turn_page(direction, event)
  if key and key.START and event ~= key.START then return end
  if state.stopped or not state.runtime.online then return end
  local page, changed = state.pager:step(direction, #pages, now_ms())
  if changed then
    show_hud((pages[page] and pages[page].title) or "")
    render()
  end
end

local function build_ui()
  local root = lv_scr_act()
  if lv_obj_clean then
    lv_obj_clean(root)
  elseif lv_clear then
    lv_clear()
  end

  pcall(lv_obj_set_style_bg_color, root, colors.bg, MAIN)
  pcall(lv_obj_set_style_bg_opa, root, 255, MAIN)
  local scrollable = rawget(_G, "LV_OBJ_FLAG_SCROLLABLE")
  if scrollable and lv_obj_clear_flag then
    pcall(lv_obj_clear_flag, root, scrollable)
  end

  if lv_canvas_create then
    if CANVAS_FMT then
      state.canvas = lv_canvas_create(root, 320, 240, CANVAS_FMT)
    else
      state.canvas = lv_canvas_create(root, 320, 240)
    end
    pcall(lv_obj_set_pos, state.canvas, 0, 0)
  end
end

local function create_client()
  return PcClient.new(config, {
    on_status = function(status, detail)
      log("status", status, detail or "")
      state.runtime:set_status(status, detail)
      render()
    end,
    on_sample = function(snapshot)
      local transition = state.runtime:apply_sample(snapshot, now_ms())
      if transition == "online" then
        set_online_page(1)
      end
      render()
    end,
  })
end

local function start_client()
  if state.client then
    state.client:stop()
  end
  state.client = create_client()
  state.client:start()
end

local function start_tick()
  if not tmr or not tmr.create then return end
  state.tick_timer = tmr.create()
  state.tick_timer:alarm(500, tmr.ALARM_AUTO, function()
    if state.stopped then return end
    local transition = state.runtime:update_presence(now_ms())
    if transition == "offline" then
      show_hud("AMBIENT")
    end
    render()
  end)
end

function state.stop(reason)
  if state.stopped then return end
  state.stopped = true
  log("stop", reason or "")
  if state.client then
    state.client:stop()
    state.client = nil
  end
  if state.tick_timer then
    pcall(function() state.tick_timer:unregister() end)
    state.tick_timer = nil
  end
  if key and key.off then
    pcall(function() key.off() end)
  end
end

if key and key.on then
  if key.LEFT then
    key.on(key.LEFT, function(event) turn_page(-1, event) end)
  end
  if key.RIGHT then
    key.on(key.RIGHT, function(event) turn_page(1, event) end)
  end
  if key.HOME then
    key.on(key.HOME, function(event)
      if not key.SHORT or event == key.SHORT then
        state.stop("home")
        if app and app.exit then app.exit() end
      end
    end)
  end
end

_G.__ysp_pc_monitor = state

build_ui()
render()
start_client()
start_tick()

return state
