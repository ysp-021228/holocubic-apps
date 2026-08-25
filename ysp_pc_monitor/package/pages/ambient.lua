local Page = { title = "AMBIENT" }

local MONTHS = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }
local DAYS = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" }

local function date_text()
  if time and time.getlocal then
    local ok, value = pcall(time.getlocal)
    if ok and type(value) == "table" then
      local year = tonumber(value.year or value[1])
      if year and year < 2024 then return "" end
      local month = tonumber(value.mon or value.month or value[2])
      local day = tonumber(value.day or value.mday or value[3])
      local wday = tonumber(value.wday or value.weekday or value[7])
      if month and day then
        if wday then wday = ((wday - 1) % 7) + 1 end
        return string.format("%s.%02d / %s", MONTHS[month] or "---", day, DAYS[wday] or "---")
      end
    end
  end
  if os and os.date then
    return os.date("%b.%d / %a"):upper()
  end
  return ""
end

function Page.render(ctx)
  local D = ctx.draw
  local C = D.palette()
  D.corner(ctx, 17, 20, 24, "tl", C.line_dim, 190)
  D.corner(ctx, 303, 20, 24, "tr", C.line_dim, 190)
  D.corner(ctx, 17, 220, 24, "bl", C.line_dim, 190)
  D.corner(ctx, 303, 220, 24, "br", C.line_dim, 190)
  D.text(ctx.canvas, 0, 42, 320, tostring(ctx.clock or "--:--"):gsub(":", " "), C.text, 76, D.ALIGN_CENTER)
  D.text(ctx.canvas, 0, 132, 320, date_text(), C.soft, 12, D.ALIGN_CENTER)
  D.text(ctx.canvas, 0, 165, 320, "PC // SLEEP", C.dim, 11, D.ALIGN_CENTER)
end

return Page
