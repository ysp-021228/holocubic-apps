local Page = { title = "THERMAL" }

local function temp_line_width(value, max_width)
  value = tonumber(value)
  if not value then return 18 end

  local pct = (value - 25) / 65
  if pct < 0 then pct = 0 end
  if pct > 1 then pct = 1 end
  return math.max(18, math.floor(max_width * pct + 0.5))
end

local function temp_level(value)
  value = tonumber(value)
  if not value then return nil end
  if value >= 85 then return 3 end
  if value >= 75 then return 2 end
  if value >= 65 then return 1 end
  return 0
end

local function temp_color(C, value, normal_color)
  local level = temp_level(value)
  if not level then return C.line_dim end
  if level >= 2 then return C.hot or C.warn end
  if level == 1 then return C.warn end
  return normal_color or C.text
end

local function hottest_temp(...)
  local hottest
  for i = 1, select("#", ...) do
    local raw_value = select(i, ...)
    local value = tonumber(raw_value)
    if value and (not hottest or value > hottest) then
      hottest = value
    end
  end
  return hottest
end

local function thermal_status(C, F, value)
  local level = temp_level(value)
  if not level then return "NO DATA", C.dim end

  local suffix = F.temp(value) .. "℃"
  if level >= 3 then return "LIMIT " .. suffix, C.hot or C.warn end
  if level == 2 then return "HOT " .. suffix, C.hot or C.warn end
  if level == 1 then return "WARM " .. suffix, C.warn end
  return "OK " .. suffix, C.ok or C.soft
end

local function draw_temp_line(ctx, x, y, value, max_width, right_aligned)
  local D = ctx.draw
  local C = D.palette()
  local has_value = tonumber(value) ~= nil
  local width = temp_line_width(value, max_width)
  local color = temp_color(C, value, C.line)
  local opacity = has_value and 215 or 160

  if right_aligned then
    D.line(ctx.canvas, x + max_width - width, y, x + max_width, y, color, opacity, 1)
  else
    D.line(ctx.canvas, x, y, x + width, y, color, opacity, 1)
  end
end

local function temp_text(F, value)
  local text = F.temp(value)
  if text == "--" then return text end
  return text .. "℃"
end

local function draw_temp_value(ctx, x, y, width, value, size, align)
  local D, F = ctx.draw, ctx.format
  local C = D.palette()
  D.text(ctx.canvas, x, y, width, temp_text(F, value), temp_color(C, value, C.text), size, align)
end

local function draw_fan(ctx, x, rpm)
  local D, F = ctx.draw, ctx.format
  local C = D.palette()
  D.text(ctx.canvas, x, 209, 56, F.num(rpm, 0), C.text, 12, D.ALIGN_LEFT)
end

function Page.render(ctx, snap)
  local D, F = ctx.draw, ctx.format
  local C = D.palette()
  local cpu, gpu = snap.cpu or {}, snap.gpu or {}
  local memory, storage, fans = snap.memory or {}, snap.storage or {}, snap.fans or {}
  local hottest = hottest_temp(cpu.temp, cpu.ccd_temp, gpu.temp, gpu.memory_temp,
    storage.ssd_temp, memory.dimm1_temp, memory.dimm3_temp)
  local status, status_color = thermal_status(C, F, hottest)

  D.header(ctx, "THERMAL", status, status_color)

  -- Primary thermal pair.
  D.text(ctx.canvas, 24, 55, 72, "CPU", C.soft, 10, D.ALIGN_LEFT)
  draw_temp_value(ctx, 24, 69, 68, cpu.temp, 27, D.ALIGN_LEFT)
  D.text(ctx.canvas, 24, 103, 86, "CCD  " .. temp_text(F, cpu.ccd_temp), temp_color(C, cpu.ccd_temp, C.soft), 11, D.ALIGN_LEFT)
  draw_temp_line(ctx, 24, 121, cpu.temp, 68, false)

  D.text(ctx.canvas, 178, 55, 118, "GPU", C.soft, 10, D.ALIGN_RIGHT)
  draw_temp_value(ctx, 208, 69, 88, gpu.temp, 27, D.ALIGN_RIGHT)
  D.text(ctx.canvas, 196, 103, 100, "VRAM  " .. temp_text(F, gpu.memory_temp), temp_color(C, gpu.memory_temp, C.soft), 11, D.ALIGN_RIGHT)
  draw_temp_line(ctx, 218, 121, gpu.temp, 68, true)

  -- Secondary devices.
  D.text(ctx.canvas, 24, 137, 72, "SSD", C.soft, 10, D.ALIGN_LEFT)
  draw_temp_value(ctx, 24, 151, 70, storage.ssd_temp, 27, D.ALIGN_LEFT)
  draw_temp_line(ctx, 24, 181, storage.ssd_temp, 54, false)

  D.text(ctx.canvas, 178, 137, 118, "MEMORY", C.soft, 10, D.ALIGN_RIGHT)
  D.text(ctx.canvas, 176, 155, 62, "D1 " .. temp_text(F, memory.dimm1_temp), temp_color(C, memory.dimm1_temp, C.soft), 10, D.ALIGN_LEFT)
  D.text(ctx.canvas, 240, 155, 62, "D3 " .. temp_text(F, memory.dimm3_temp), temp_color(C, memory.dimm3_temp, C.soft), 10, D.ALIGN_LEFT)
  draw_temp_line(ctx, 176, 181, memory.dimm1_temp, 44, false)
  draw_temp_line(ctx, 240, 181, memory.dimm3_temp, 44, false)

  -- Cooling telemetry rail.
  D.text(ctx.canvas, 24, 190, 96, "FANS // RPM", C.soft, 9, D.ALIGN_LEFT)
  draw_fan(ctx, 24, fans.board1_rpm)
  draw_fan(ctx, 94, fans.board2_rpm)
  draw_fan(ctx, 164, fans.board3_rpm)
  draw_fan(ctx, 234, fans.board4_rpm)

  D.footer(ctx)
end

return Page
