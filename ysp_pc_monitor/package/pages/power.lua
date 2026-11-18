local Page = { title = "POWER" }

local function draw_component(ctx, x, label, component, color)
  local D, F = ctx.draw, ctx.format
  local C = D.palette()
  local clock = component.clock and F.clock(component.clock) .. " " .. F.clock_unit(component.clock) or "--"
  D.text(ctx.canvas, x, 109, 134, label, color, 11, D.ALIGN_LEFT)
  D.metric(ctx, x, 122, 102, F.num(component.power, 1), "W", 24, 12, 12)
  D.text(ctx.canvas, x, 152, 134, clock, C.soft, 12, D.ALIGN_LEFT)
end

local function power_points(history, width, height)
  if type(history) ~= "table" or #history < 2 then return nil end

  local first = 1
  local count = #history
  local min_value, max_value

  for i = first, count do
    local value = tonumber(history[i])
    if value then
      min_value = min_value and math.min(min_value, value) or value
      max_value = max_value and math.max(max_value, value) or value
    end
  end

  if not min_value or not max_value then return nil end

  local points = {}
  local span = max_value - min_value
  local out_i = 1
  for i = first, count do
    local value = tonumber(history[i])
    if value then
      local x = math.floor((out_i - 1) * width / math.max(1, count - 1) + 0.5)
      local y
      if span > 0 then
        y = math.floor(height - ((value - min_value) / span) * height + 0.5)
      else
        y = math.floor(height / 2 + 0.5)
      end
      points[#points + 1] = { x, y }
      out_i = out_i + 1
    end
  end

  return #points >= 2 and points or nil
end

function Page.render(ctx, snap)
  local D, F = ctx.draw, ctx.format
  local C = D.palette()
  local cpu, gpu = snap.cpu or {}, snap.gpu or {}
  local cpu_power = tonumber(cpu.power)
  local gpu_power = tonumber(gpu.power)
  local total = (cpu_power or 0) + (gpu_power or 0)
  local has_total = cpu_power ~= nil or gpu_power ~= nil

  D.header(ctx, "POWER", "")

  D.text(ctx.canvas, 14, 60, 104, "CPU + GPU", C.power, 12, D.ALIGN_LEFT)
  if (cpu_power == nil) ~= (gpu_power == nil) then
    D.text(ctx.canvas, 14, 77, 104, "PARTIAL DATA", C.warn, 10, D.ALIGN_LEFT)
  end
  D.metric(ctx, 120, 43, 186, F.num(has_total and total or nil, 1), "W", 44, 16, 18)
  D.rule(ctx, 14, 101, 306, 101)

  draw_component(ctx, 14, "CPU POWER", cpu, C.cpu)
  draw_component(ctx, 172, "GPU POWER", gpu, C.gpu)
  D.rule(ctx, 160, 109, 160, 164)
  D.rule(ctx, 14, 171, 306, 171)

  D.text(ctx.canvas, 14, 177, 130, "POWER HISTORY", C.dim, 11, D.ALIGN_LEFT)
  D.chart_grid(ctx, 14, 194, 292, 25)
  D.sparkline(ctx, 14, 194, power_points(snap.power_history, 292, 25), C.power)
end

return Page
