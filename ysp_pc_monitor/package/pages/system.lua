local Page = { title = "SYSTEM" }

local function usage_color(C, value)
  value = tonumber(value)
  if not value then return C.text end
  if value >= 90 then return C.hot or C.warn end
  if value >= 75 then return C.warn end
  return C.text
end

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

local function draw_trace(ctx, x, y, points, color)
  if not points or #points < 2 then return end

  local D = ctx.draw
  local C = D.palette()
  for i = 2, #points do
    local a = points[i - 1]
    local b = points[i]
    D.line(ctx.canvas, x + a[1], y + a[2], x + b[1], y + b[2], C.off, 175, 3)
    D.line(ctx.canvas, x + a[1], y + a[2], x + b[1], y + b[2], color, 255, 1)
  end
end

local function draw_legend(ctx, x, label, color)
  local D = ctx.draw
  D.line(ctx.canvas, x, 188, x + 8, 188, color, 235, 1)
  D.text(ctx.canvas, x + 11, 184, 28, label, color, 8, D.ALIGN_LEFT)
end

local function draw_usage_bar(ctx, x, y, width, value, color)
  local D = ctx.draw
  local C = D.palette()
  local pct = math.max(0, math.min(100, tonumber(value) or 0))
  local fill_w = math.floor(width * pct / 100 + 0.5)
  D.line(ctx.canvas, x, y, x + width, y, C.line_dim, 220, 1)
  D.line(ctx.canvas, x, y, x + fill_w, y, color or C.soft, 235, 1)
  D.line(ctx.canvas, x + fill_w, y - 4, x + fill_w, y + 4, color or C.soft, 235, 1)
end

local function draw_usage_trace(ctx, history)
  local D = ctx.draw
  local C = D.palette()
  local x, y, width, height = 22, 198, 276, 24

  D.text(ctx.canvas, 16, 184, 42, "LOAD", C.dim, 8, D.ALIGN_LEFT)
  draw_legend(ctx, 70, "CPU", C.cpu or C.accent)
  draw_legend(ctx, 118, "GPU", C.gpu or C.ok)
  draw_legend(ctx, 166, "MEM", C.memory or C.warn)

  D.line(ctx.canvas, x, y, x + width, y, C.line_dim, 35, 1)
  D.line(ctx.canvas, x, y + math.floor(height / 2), x + width, y + math.floor(height / 2), C.line_dim, 30, 1)
  D.line(ctx.canvas, x, y + height, x + width, y + height, C.line_dim, 55, 1)

  history = history or {}
  draw_trace(ctx, x, y, usage_points(history.cpu, width, height), C.cpu or C.accent)
  draw_trace(ctx, x, y, usage_points(history.gpu, width, height), C.gpu or C.ok)
  draw_trace(ctx, x, y, usage_points(history.memory, width, height), C.memory or C.warn)
end

function Page.render(ctx, snap)
  local D, F = ctx.draw, ctx.format
  local C = D.palette()
  local cpu, gpu, memory = snap.cpu or {}, snap.gpu or {}, snap.memory or {}
  local cpu_color = usage_color(C, cpu.load)
  local gpu_color = usage_color(C, gpu.load)
  local mem_color = usage_color(C, memory.load)

  remember_load_sample(snap, cpu, gpu, memory)

  D.header(ctx, "SYSTEM", ctx.clock)

  D.partial_box(ctx, 21, 51, 122, 74)
  D.text(ctx.canvas, 27, 57, 60, "CPU", C.dim, 8, D.ALIGN_LEFT)
  D.text(ctx.canvas, 76, 70, 64, F.pct(cpu.load), cpu_color, 38, D.ALIGN_LEFT)
  D.text(ctx.canvas, 27, 106, 46, F.temp(cpu.temp) .. "C", C.soft, 12, D.ALIGN_LEFT)
  D.text(ctx.canvas, 80, 106, 60, F.clock(cpu.clock) .. " " .. F.clock_unit(cpu.clock), C.soft, 12, D.ALIGN_RIGHT)

  D.partial_box(ctx, 177, 51, 122, 74)
  D.text(ctx.canvas, 235, 57, 58, "GPU", C.dim, 8, D.ALIGN_RIGHT)
  D.text(ctx.canvas, 180, 70, 64, F.pct(gpu.load), gpu_color, 38, D.ALIGN_RIGHT)
  D.text(ctx.canvas, 177, 106, 48, F.temp(gpu.temp) .. "C", C.soft, 12, D.ALIGN_LEFT)
  D.text(ctx.canvas, 233, 106, 60, F.clock(gpu.clock) .. " " .. F.clock_unit(gpu.clock), C.soft, 12, D.ALIGN_RIGHT)

  D.text(ctx.canvas, 16, 141, 80, "MEMORY", C.dim, 8, D.ALIGN_LEFT)
  D.text(ctx.canvas, 16, 157, 44, F.pct(memory.load), mem_color, 17, D.ALIGN_LEFT)
  draw_usage_bar(ctx, 70, 163, 232, memory.load, mem_color)

  draw_usage_trace(ctx, Page._load_history)
end

return Page
