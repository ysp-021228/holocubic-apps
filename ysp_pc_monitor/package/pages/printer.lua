local Page = { title = "BAMBU X2D" }

local function integer(value)
  return type(value) == "number" and math.tointeger(value) or nil
end

local function temperature(actual, target)
  actual, target = integer(actual), integer(target)
  if not actual then return "--" end
  if not target then return string.format("%d C", actual) end
  return string.format("%d / %d C", actual, target)
end

function Page.render(ctx, sample)
  local draw, cvs = ctx.draw, ctx.canvas
  local c = draw.palette()
  local function text(x, y, w, value, size, color, align)
    draw.text(cvs, x, y, w, value, color or c.text, size, align)
  end

  local status_color = c.ok
  if not sample or sample.phase == "PAUSED" then status_color = c.warn
  elseif sample.phase == "ERROR" then status_color = c.hot
  elseif sample.phase == "IDLE" or sample.phase == "UNKNOWN" then status_color = c.soft end
  local status = sample and sample.phase or "NO DATA"
  if ctx.stale then status, status_color = "STALE DATA", c.warn end
  text(14, 15, 114, Page.title, 16)
  text(131, 18, 175, status, 12, status_color, draw.ALIGN_RIGHT)
  draw.rule(ctx, 14, 39, 306, 39)
  if not sample then
    text(14, 95, 292, "X2D // NO DATA", 24, c.text, draw.ALIGN_CENTER)
    text(14, 133, 292, "Waiting for Windows bridge", 12, c.soft, draw.ALIGN_CENTER)
    return
  end

  local percent = integer(sample.percent)
  local eta = integer(sample.remainingMin)
  local layer, total = integer(sample.layer), integer(sample.totalLayers)
  text(14, 50, 114, "PROGRESS", 10, c.soft)
  text(14, 66, 108, percent and (percent .. "%") or "--", 28, c.gpu)
  text(127, 50, 91, "TIME LEFT", 10, c.soft)
  text(127, 73, 91, eta and (eta >= 60 and string.format("%dh %02dm", eta // 60, eta % 60) or (eta .. " min")) or "--", 16)
  text(224, 50, 82, "LAYERS", 10, c.soft, draw.ALIGN_RIGHT)
  text(221, 75, 85, layer and total and string.format("%d/%d", layer, total) or "--", 12, c.text, draw.ALIGN_RIGHT)
  if percent then draw.progress_line(ctx, 14, 110, 292, percent)
  else draw.rule(ctx, 14, 110, 306, 110) end

  text(14, 126, 140, "LEFT NOZZLE", 10, c.soft)
  text(14, 143, 140, temperature(sample.leftNozzle), 16, c.power)
  text(169, 126, 137, "RIGHT NOZZLE", 10, c.soft)
  text(169, 143, 137, temperature(sample.rightNozzle), 16, c.power)
  text(14, 174, 84, "BED", 10, c.soft)
  text(107, 174, 85, "CHAMBER", 10, c.soft)
  text(206, 174, 100, "FILAMENT", 10, c.soft)
  text(14, 190, 90, temperature(sample.bed, sample.bedTarget), 12, c.power)
  text(107, 190, 90, temperature(sample.chamber), 12)
  local material = type(sample.filament) == "string" and #sample.filament <= 12 and sample.filament or nil
  local remaining = integer(sample.filamentRemaining)
  local filament = material and remaining and (material .. " " .. remaining .. "%") or material or "--"
  text(206, 190, 100, filament, 10)

  local humidity = integer(sample.amsHumidity)
  if humidity and (humidity < 1 or humidity > 100) then humidity = nil end
  draw.rule(ctx, 14, 215, 306, 215)
  text(14, 222, 160, "AMS HUMIDITY", 12, c.soft)
  text(185, 220, 121, humidity and (humidity .. "% RH") or "--", 14,
    humidity and c.cpu or c.soft, draw.ALIGN_RIGHT)
end

return Page
