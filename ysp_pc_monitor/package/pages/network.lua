local Page = { title = "NETWORK" }

local function draw_rate(ctx, y, direction, label, value, color)
  local D, F = ctx.draw, ctx.format
  D.arrow(ctx, 20, y + 26, direction, color)
  D.text(ctx.canvas, 34, y + 23, 99, label, color, 12, D.ALIGN_LEFT)
  D.metric(ctx, 135, y + 9, 171, F.rate(value), F.rate_unit(value), 34, 12, 34)
  D.rule(ctx, 14, y + 62, 306, y + 62)
end

function Page.render(ctx, snap)
  local D, C = ctx.draw, ctx.draw.palette()
  local network = snap.network or {}

  D.header(ctx, "NETWORK", "ONLINE", C.ok)
  draw_rate(ctx, 40, "up", "UPLOAD", network.up, C.cpu)
  draw_rate(ctx, 103, "down", "DOWNLOAD", network.down, C.gpu)

  D.text(ctx.canvas, 14, 174, 90, "BRIDGE", C.dim, 11, D.ALIGN_LEFT)
  D.text(ctx.canvas, 14, 189, 292, tostring(ctx.config.host) .. ":" .. tostring(ctx.config.port), C.text, 16, D.ALIGN_LEFT)
end

return Page
