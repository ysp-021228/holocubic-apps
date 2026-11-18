local Page = { title = "THERMAL" }

local function temp_level(value)
  value = tonumber(value)
  if not value then return nil end
  if value >= 85 then return 3 end
  if value >= 75 then return 2 end
  if value >= 65 then return 1 end
  return 0
end

local function temp_color(C, value)
  local level = temp_level(value)
  if not level then return C.dim end
  if level >= 2 then return C.hot end
  if level == 1 then return C.warn end
  return C.text
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

local function temp_text(F, value)
  local text = F.temp(value)
  return text == "--" and text or text .. " C"
end

local function thermal_status(C, F, value)
  local level = temp_level(value)
  if not level then return "NO DATA", C.dim end

  local suffix = "  " .. temp_text(F, value)
  if level >= 3 then return "LIMIT" .. suffix, C.hot end
  if level == 2 then return "HOT" .. suffix, C.hot end
  if level == 1 then return "WARM" .. suffix, C.warn end
  return "OK" .. suffix, C.ok
end

local function draw_primary(ctx, x, label, value, color, sub_label, sub_value)
  local D, F = ctx.draw, ctx.format
  local C = D.palette()
  D.text(ctx.canvas, x, 46, 136, label, color, 11, D.ALIGN_LEFT)
  D.metric(ctx, x, 58, 80, F.temp(value), "C", 33, 12, 10, temp_color(C, value))
  D.text(ctx.canvas, x, 101, 40, sub_label, C.dim, 12, D.ALIGN_LEFT)
  D.text(ctx.canvas, x + 43, 101, 50, temp_text(F, sub_value), temp_color(C, sub_value), 12, D.ALIGN_LEFT)
end

local function draw_secondary(ctx, x, label, value)
  local D, F = ctx.draw, ctx.format
  local C = D.palette()
  D.text(ctx.canvas, x, 126, 80, label, C.dim, 11, D.ALIGN_LEFT)
  D.text(ctx.canvas, x, 141, 84, temp_text(F, value), temp_color(C, value), 18, D.ALIGN_LEFT)
end

local function draw_fan(ctx, x, number, rpm)
  local D, F = ctx.draw, ctx.format
  local C = D.palette()
  D.text(ctx.canvas, x, 189, 64, "#" .. number, C.dim, 10, D.ALIGN_LEFT)
  D.text(ctx.canvas, x, 202, 64, F.num(rpm, 0), rpm and C.text or C.dim, 15, D.ALIGN_LEFT)
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
  draw_primary(ctx, 14, "CPU TEMP", cpu.temp, C.cpu, "CCD", cpu.ccd_temp)
  draw_primary(ctx, 172, "GPU TEMP", gpu.temp, C.gpu, "VRAM", gpu.memory_temp)
  D.rule(ctx, 160, 47, 160, 115)
  D.rule(ctx, 14, 119, 306, 119)

  draw_secondary(ctx, 14, "SSD", storage.ssd_temp)
  draw_secondary(ctx, 122, "DIMM 1", memory.dimm1_temp)
  draw_secondary(ctx, 220, "DIMM 3", memory.dimm3_temp)
  D.rule(ctx, 111, 126, 111, 162)
  D.rule(ctx, 209, 126, 209, 162)
  D.rule(ctx, 14, 167, 306, 167)

  D.text(ctx.canvas, 14, 172, 160, "BOARD FANS / RPM", C.dim, 11, D.ALIGN_LEFT)
  draw_fan(ctx, 14, 1, fans.board1_rpm)
  draw_fan(ctx, 89, 2, fans.board2_rpm)
  draw_fan(ctx, 164, 3, fans.board3_rpm)
  draw_fan(ctx, 239, 4, fans.board4_rpm)
end

return Page
