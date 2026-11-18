local Draw = {}

Draw.ALIGN_LEFT = rawget(_G, "LV_TEXT_ALIGN_LEFT") or 0
Draw.ALIGN_CENTER = rawget(_G, "LV_TEXT_ALIGN_CENTER") or 1
Draw.ALIGN_RIGHT = rawget(_G, "LV_TEXT_ALIGN_RIGHT") or 2

local function call(fn, ...)
  if not fn then return false end
  local ok = pcall(fn, ...)
  return ok
end

function Draw.palette()
  return {
    off = 0x000000,
    text = 0xF5F6F9,
    soft = 0xB0BAC8,
    dim = 0xB0BAC8,
    faint = 0x4D5865,
    line = 0x7C8B9B,
    line_dim = 0x3E4754,
    accent = 0x9BB7C8,
    cpu = 0x76D7FF,
    gpu = 0x83EFBE,
    memory = 0xFBD17A,
    power = 0xFFBC78,
    warn = 0xFFD18B,
    hot = 0xFF9B88,
    ok = 0x83EFBE,
  }
end

function Draw.begin(canvas)
  if call(lv_canvas_frame_begin, canvas) then return true end
  if call(lv_canvas_begin, canvas) then return true end
  return false
end

function Draw.finish(canvas, explicit)
  if not explicit then return end
  if not call(lv_canvas_frame_end, canvas) then
    call(lv_canvas_end, canvas)
  end
end

function Draw.fill(canvas)
  -- The physical transparent display treats black pixels as non-emissive.
  -- Keep this as a buffer clear only; pages should not draw filled panels.
  call(lv_canvas_fill_bg, canvas, 0x000000, 255)
end

function Draw.rect(canvas, x, y, w, h, color, opacity, radius)
  if not lv_canvas_draw_rect then return end
  local ok = call(lv_canvas_draw_rect, canvas, math.floor(x), math.floor(y),
    math.floor(w), math.floor(h), color or 0, opacity or 255, radius or 0)
  if not ok then
    call(lv_canvas_draw_rect, canvas, math.floor(x), math.floor(y),
      math.floor(w), math.floor(h), {
        bg_color = color or 0,
        bg_opa = opacity or 255,
        border_width = 0,
        radius = radius or 0,
      })
  end
end

function Draw.line(canvas, x1, y1, x2, y2, color, opacity, width)
  call(lv_canvas_draw_line, canvas, math.floor(x1 + 0.5), math.floor(y1 + 0.5),
    math.floor(x2 + 0.5), math.floor(y2 + 0.5), color or 0xFFFFFF,
    opacity or 255, width or 1)
end

function Draw.text(canvas, x, y, width, text, color, size, align, opacity, font_handle)
  if not lv_canvas_draw_text then return end
  local descriptor = {
    color = color or 0xFFFFFF,
    opa = opacity or 255,
    align = align or Draw.ALIGN_LEFT,
    font_size = size or 10,
    font_handle = font_handle,
  }
  local ok = call(lv_canvas_draw_text, canvas, math.floor(x), math.floor(y),
    math.max(1, math.floor(width)), tostring(text or ""), descriptor)
  if not ok then
    call(lv_canvas_draw_text, canvas, math.floor(x), math.floor(y),
      math.max(1, math.floor(width)), tostring(text or ""), color or 0xFFFFFF,
      opacity or 255, align or Draw.ALIGN_LEFT, size or 10)
  end
end

function Draw.header(ctx, title, right_text, right_color)
  local c = Draw.palette()
  if ctx.stale then
    right_text, right_color = "STALE DATA", c.warn
  end
  Draw.text(ctx.canvas, 14, 15, 150, title, c.text, 16, Draw.ALIGN_LEFT)
  Draw.text(ctx.canvas, 166, 18, 140, right_text or ctx.clock or "--:--", right_color or c.soft, 12, Draw.ALIGN_RIGHT)
  Draw.rule(ctx, 14, 39, 306, 39)
end

function Draw.rule(ctx, x1, y1, x2, y2)
  Draw.line(ctx.canvas, x1, y1, x2, y2, Draw.palette().line_dim, 255, 1)
end

-- These offsets are the measured bottom edges of the numeral glyphs on the
-- firmware's built-in fonts. Unsupported large sizes fall back to a small font.
local metric_baseline = { [12] = 11, [16] = 14, [24] = 21, [28] = 24 }

-- Reserve a fixed unit column so the numbers stay aligned across rows.
-- The formatter's missing-value marker is drawn without a unit.
function Draw.metric(ctx, x, y, width, value, unit, size, unit_size, unit_width, color)
  local c = Draw.palette()
  local has_value = value ~= "--"
  local number_width = width - unit_width - 4
  local number_size = math.min(size, 28)
  unit_size = unit_size >= 16 and 16 or 12
  local number_y = y + math.floor((size - number_size) / 2)
  Draw.text(ctx.canvas, x, number_y, number_width, value,
    has_value and (color or c.text) or c.dim, number_size, Draw.ALIGN_RIGHT)
  if has_value then
    local unit_y = number_y + metric_baseline[number_size] - metric_baseline[unit_size]
    Draw.text(ctx.canvas, x + number_width + 4, unit_y,
      unit_width, unit, c.soft, unit_size, Draw.ALIGN_LEFT)
  end
end

function Draw.chart_grid(ctx, x, y, width, height)
  Draw.rule(ctx, x, y, x + width, y)
  Draw.rule(ctx, x, y + math.floor(height / 2), x + width, y + math.floor(height / 2))
  Draw.rule(ctx, x, y + height, x + width, y + height)
end

function Draw.corner(ctx, x, y, size, mode, color, opacity)
  local cvs = ctx.canvas
  local c = color or Draw.palette().line
  local o = opacity or 200
  size = size or 16
  if mode == "tl" then
    Draw.line(cvs, x, y, x + size, y, c, o, 1)
    Draw.line(cvs, x, y, x, y + size, c, o, 1)
  elseif mode == "tr" then
    Draw.line(cvs, x - size, y, x, y, c, o, 1)
    Draw.line(cvs, x, y, x, y + size, c, o, 1)
  elseif mode == "bl" then
    Draw.line(cvs, x, y - size, x, y, c, o, 1)
    Draw.line(cvs, x, y, x + size, y, c, o, 1)
  else
    Draw.line(cvs, x - size, y, x, y, c, o, 1)
    Draw.line(cvs, x, y - size, x, y, c, o, 1)
  end
end

function Draw.partial_box(ctx, x, y, w, h)
  local c = Draw.palette()
  Draw.corner(ctx, x, y, 16, "tl", c.line, 185)
  Draw.corner(ctx, x + w, y + h, 16, "br", c.line, 185)
end

function Draw.progress_line(ctx, x, y, w, pct)
  local c = Draw.palette()
  pct = math.max(0, math.min(100, tonumber(pct) or 0))
  local fill_w = math.floor(w * pct / 100 + 0.5)
  Draw.line(ctx.canvas, x, y, x + w, y, c.line_dim, 220, 1)
  Draw.line(ctx.canvas, x, y, x + fill_w, y, c.soft, 235, 1)
  Draw.line(ctx.canvas, x + fill_w, y - 4, x + fill_w, y + 4, c.soft, 235, 1)
end

function Draw.arrow(ctx, x, y, direction, color)
  local c = color or Draw.palette().soft
  if direction == "up" then
    Draw.line(ctx.canvas, x, y + 10, x, y, c, 230, 1)
    Draw.line(ctx.canvas, x, y, x - 3, y + 4, c, 230, 1)
    Draw.line(ctx.canvas, x, y, x + 3, y + 4, c, 230, 1)
  else
    Draw.line(ctx.canvas, x, y, x, y + 10, c, 230, 1)
    Draw.line(ctx.canvas, x, y + 10, x - 3, y + 6, c, 230, 1)
    Draw.line(ctx.canvas, x, y + 10, x + 3, y + 6, c, 230, 1)
  end
end

function Draw.page_rail(ctx)
  if not ctx.online then return end
  local c = Draw.palette()
  local y = 224
  local xs = { 205, 238, 271, 304 }
  for i = 1, 4 do
    local active = i == (tonumber(ctx.page) or 1)
    local x = xs[i]
    Draw.text(ctx.canvas, x, y, 14, string.format("%02d", i),
      active and c.text or c.dim, 7, Draw.ALIGN_LEFT)
    if i < 4 then
      Draw.line(ctx.canvas, x + 16, y + 4, xs[i + 1] - 5, y + 4,
        active and c.line or c.line_dim, active and 230 or 180, 1)
    end
  end
end

function Draw.sparkline(ctx, x, y, points, color, dash, gap)
  if not points or #points < 2 then return end
  local c = color or Draw.palette().line
  for i = 2, #points do
    local a, b = points[i - 1], points[i]
    if dash and b[1] > a[1] then
      local period = dash + gap
      local slope = (b[2] - a[2]) / (b[1] - a[1])
      local start = a[1] - a[1] % period
      for left = start, b[1] - 1, period do
        local from, to = math.max(a[1], left), math.min(b[1], left + dash)
        if from <= to then
          Draw.line(ctx.canvas, x + from, y + a[2] + slope * (from - a[1]),
            x + to, y + a[2] + slope * (to - a[1]), c, 255, 1)
        end
      end
    else
      Draw.line(ctx.canvas, x + a[1], y + a[2], x + b[1], y + b[2], c, 255, 1)
    end
  end
end

function Draw.footer(ctx)
  -- Page numbers are intentionally hidden in the transparent HUD design.
end

-- Legacy helpers kept for compatibility with any interim page experiments.
function Draw.card(ctx, x, y, w, h, label, value, unit, color)
  local c = Draw.palette()
  Draw.text(ctx.canvas, x, y, w, label, c.dim, 10, Draw.ALIGN_LEFT)
  Draw.text(ctx.canvas, x, y + 16, w, value or "--", color or c.text, 20, Draw.ALIGN_LEFT)
  if unit and unit ~= "" then
    Draw.text(ctx.canvas, x + w - 36, y + 21, 30, unit, c.dim, 9, Draw.ALIGN_RIGHT)
  end
end

function Draw.kv(ctx, y, label, value, unit, color)
  local c = Draw.palette()
  Draw.text(ctx.canvas, 16, y, 126, label, c.dim, 11, Draw.ALIGN_LEFT)
  Draw.text(ctx.canvas, 150, y - 2, 104, value or "--", color or c.text, 17, Draw.ALIGN_RIGHT)
  Draw.text(ctx.canvas, 258, y + 1, 46, unit or "", c.dim, 10, Draw.ALIGN_LEFT)
end

function Draw.bar(ctx, x, y, w, h, value, color)
  Draw.progress_line(ctx, x, y + math.floor(h / 2), w, value)
end

return Draw
