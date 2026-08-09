local Page = { title = "NETWORK" }

function Page.render(ctx, snap)
  local D, F = ctx.draw, ctx.format
  local C = D.palette()
  local network = snap.network or {}

  D.header(ctx, "NETWORK", "ONLINE *")

  D.text(ctx.canvas, 0, 55, 320, "LINK", C.soft, 12, D.ALIGN_CENTER)
  D.text(ctx.canvas, 52, 86, 82, "UPLOAD", C.dim, 8, D.ALIGN_CENTER)
  D.arrow(ctx, 68, 103, "up", C.soft)
  D.text(ctx.canvas, 52, 105, 82, F.rate(network.up), C.text, 30, D.ALIGN_CENTER)
  D.text(ctx.canvas, 52, 136, 82, F.rate_unit(network.up), C.soft, 10, D.ALIGN_CENTER)

  D.text(ctx.canvas, 186, 86, 82, "DOWNLOAD", C.dim, 8, D.ALIGN_CENTER)
  D.arrow(ctx, 202, 103, "down", C.soft)
  D.text(ctx.canvas, 186, 105, 82, F.rate(network.down), C.text, 30, D.ALIGN_CENTER)
  D.text(ctx.canvas, 186, 136, 82, F.rate_unit(network.down), C.soft, 10, D.ALIGN_CENTER)

  D.text(ctx.canvas, 21, 185, 270, "BRIDGE  " .. tostring(ctx.config.host) .. " : " .. tostring(ctx.config.port), C.soft, 10, D.ALIGN_LEFT)
end

return Page
