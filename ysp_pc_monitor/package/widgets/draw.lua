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
    text = 0xF3F7FB,
    soft = 0xBAC5D2,
    dim = 0x8492A2,
    faint = 0x4D5865,
    line = 0x7C8B9B,
    line_dim = 0x303842,
    accent = 0x9BB7C8,
    cpu = 0x43C8FF,
    gpu = 0x62E493,
    memory = 0xD7B56D,
    warn = 0xD7B56D,
    hot = 0xE87D72,
    ok = 0x9CCBB4,
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
  Draw.text(ctx.canvas, 10, 10, 190, title, c.text, 12, Draw.ALIGN_LEFT)
  Draw.text(ctx.canvas, 214, 10, 96, right_text or ctx.clock or "--:--", right_color or c.soft, 10, Draw.ALIGN_RIGHT)
  Draw.line(ctx.canvas, 10, 30, 310, 30, c.line, 190, 1)
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

function Draw.sparkline(ctx, x, y, points, color)
  if not points or #points < 2 then return end
  local c = color or Draw.palette().line
  for i = 2, #points do
    local a = points[i - 1]
    local b = points[i]
    Draw.line(ctx.canvas, x + a[1], y + a[2], x + b[1], y + b[2], c, 210, 1)
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
