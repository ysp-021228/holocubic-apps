local Page = { title = "SYSTEM" }

local function push_history(history, value, max_samples)
  value = tonumber(value)
  if not value then return end

  history[#history + 1] = math.max(0, math.min(100, value))
  while #history > max_samples do
    table.remove(history, 1)
  end
end

local function remember_load_sample(snap, cpu, gpu, memory)
  local key = snap.received_at
  if key == nil or key == 0 then
    key = tostring(cpu.load or "") .. "|" .. tostring(gpu.load or "") .. "|" .. tostring(memory.load or "")
  end
  if key == Page._last_load_key then return end

  Page._last_load_key = key
  Page._load_history = Page._load_history or { cpu = {}, gpu = {}, memory = {} }
  local max_samples = 40

  push_history(Page._load_history.cpu, cpu.load, max_samples)
  push_history(Page._load_history.gpu, gpu.load, max_samples)
  push_history(Page._load_history.memory, memory.load, max_samples)
end

local function usage_points(history, width, height)
  if type(history) ~= "table" or #history < 2 then return nil end

  local points = {}
  for i = 1, #history do
    local value = tonumber(history[i])
    if value then
      value = math.max(0, math.min(100, value))
      local x = math.floor((#points) * width / math.max(1, #history - 1) + 0.5)
      local y = math.floor(height - (value / 100) * height + 0.5)
      points[#points + 1] = { x, y }
    end
  end

  return #points >= 2 and points or nil
end

local function draw_legend(ctx, x, label, color, dash, gap)
  local D = ctx.draw
  D.sparkline(ctx, x, 166, {{0, 0}, {10, 0}}, color, dash, gap)
  D.text(ctx.canvas, x + 13, 159, 28, label, color, 10, D.ALIGN_LEFT)
end

local function draw_usage_trace(ctx, history)
  local D, C = ctx.draw, ctx.draw.palette()
  local x, y, width, height = 14, 180, 292, 39

  D.text(ctx.canvas, x, 158, 110, "LOAD HISTORY", C.dim, 11, D.ALIGN_LEFT)
  draw_legend(ctx, 171, "CPU", C.cpu)
  draw_legend(ctx, 218, "GPU", C.gpu, 5, 3)
  draw_legend(ctx, 265, "MEM", C.memory, 1, 4)

  D.chart_grid(ctx, x, y, width, height)
  history = history or {}
  D.sparkline(ctx, x, y, usage_points(history.cpu, width, height), C.cpu)
  D.sparkline(ctx, x, y, usage_points(history.gpu, width, height), C.gpu, 5, 3)
  D.sparkline(ctx, x, y, usage_points(history.memory, width, height), C.memory, 1, 4)
end

local function draw_load(ctx, x, label, reading, color)
  local D, F = ctx.draw, ctx.format
  local C = D.palette()
  local temp = reading.temp and F.temp(reading.temp) .. " C" or "--"
  local clock = reading.clock and F.clock(reading.clock) .. " " .. F.clock_unit(reading.clock) or "--"
  D.text(ctx.canvas, x, 46, 139, label, color, 11, D.ALIGN_LEFT)
  D.metric(ctx, x, 58, 91, F.num(reading.load, 0), "%", 36, 13, 13)
  D.text(ctx.canvas, x, 103, 139, temp .. "  /  " .. clock, C.soft, 12, D.ALIGN_LEFT)
end

function Page.render(ctx, snap)
  local D, F = ctx.draw, ctx.format
  local C = D.palette()
  local cpu, gpu, memory = snap.cpu or {}, snap.gpu or {}, snap.memory or {}

  if not snap.load_history then remember_load_sample(snap, cpu, gpu, memory) end
  D.header(ctx, "SYSTEM", ctx.clock)

  draw_load(ctx, 14, "CPU LOAD", cpu, C.cpu)
  draw_load(ctx, 172, "GPU LOAD", gpu, C.gpu)
  D.rule(ctx, 160, 47, 160, 115)
  D.rule(ctx, 14, 121, 306, 121)

  local pct = math.max(0, math.min(100, tonumber(memory.load) or 0))
  D.text(ctx.canvas, 14, 131, 76, "MEMORY", C.dim, 11, D.ALIGN_LEFT)
  D.line(ctx.canvas, 96, 138, 247, 138, C.line_dim, 255, 3)
  if pct > 0 then
    D.line(ctx.canvas, 96, 138, 96 + 151 * pct / 100, 138, C.memory, 255, 3)
  end
  D.metric(ctx, 251, 127, 55, F.num(memory.load, 0), "%", 16, 11, 11)
  D.rule(ctx, 14, 152, 306, 152)

  draw_usage_trace(ctx, snap.load_history or Page._load_history)
end

return Page
