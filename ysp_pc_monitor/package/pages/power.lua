local Page = { title = "POWER" }

local function watt_text(F, value)
  if tonumber(value) == nil then return "--" end
  return F.num(value, 1)
end

local function watt_label(F, value)
  if tonumber(value) == nil then return "--" end
  return F.num(value, 1) .. " W"
end

local function draw_watts(ctx, x, y, number_width, unit_x, unit_y, value, number_size, unit_size, align)
  local D, F = ctx.draw, ctx.format
  local C = D.palette()
  D.text(ctx.canvas, x, y, number_width, watt_text(F, value), C.text, number_size, align)
  D.text(ctx.canvas, unit_x, unit_y, 24, "W", C.soft, unit_size, D.ALIGN_LEFT)
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

  D.header(ctx, "POWER", "COMPUTE")

  D.text(ctx.canvas, 0, 51, 320, "CPU + GPU", C.dim, 8, D.ALIGN_CENTER)
  D.text(ctx.canvas, 0, 59, 320, watt_label(F, has_total and total or nil), C.text, 54, D.ALIGN_CENTER)

  D.line(ctx.canvas, 44, 134, 276, 134, C.line, 180, 1)
  D.text(ctx.canvas, 17, 150, 90, "CPU POWER", C.dim, 8, D.ALIGN_LEFT)
  draw_watts(ctx, 17, 164, 68, 90, 170, cpu.power, 22, 10, D.ALIGN_RIGHT)
  D.text(ctx.canvas, 17, 188, 88, F.clock(cpu.clock) .. " " .. F.clock_unit(cpu.clock), C.dim, 8, D.ALIGN_LEFT)

  D.text(ctx.canvas, 202, 150, 90, "GPU POWER", C.dim, 8, D.ALIGN_RIGHT)
  draw_watts(ctx, 202, 164, 72, 279, 170, gpu.power, 22, 10, D.ALIGN_RIGHT)
  D.text(ctx.canvas, 204, 188, 88, F.clock(gpu.clock) .. " " .. F.clock_unit(gpu.clock), C.dim, 8, D.ALIGN_RIGHT)

  local points = power_points(snap.power_history, 244, 22)
  if points then
    D.sparkline(ctx, 38, 198, points, C.line)
  end
  D.line(ctx.canvas, 38, 222, 282, 222, C.line_dim, 190, 1)
end

return Page
