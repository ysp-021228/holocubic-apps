local Format = {}

function Format.num(value, digits, fallback)
  value = tonumber(value)
  if value == nil then return fallback or "--" end
  digits = digits or 0
  if digits <= 0 then return string.format("%d", math.floor(value + 0.5)) end
  return string.format("%." .. tostring(digits) .. "f", value)
end

function Format.pct(value)
  return Format.num(value, 0) .. "%"
end

function Format.temp(value)
  if tonumber(value) == nil then return "--" end
  return Format.num(value, 0)
end

function Format.watt(value)
  if tonumber(value) == nil then return "--" end
  return Format.num(value, 0)
end

function Format.clock(value)
  value = tonumber(value)
  if value == nil then return "--" end
  if value >= 1000 then
    return string.format("%.2f", value / 1000)
  end
  return Format.num(value, 0)
end

function Format.clock_unit(value)
  value = tonumber(value)
  if value and value >= 1000 then return "GHz" end
  return "MHz"
end

function Format.rate(value)
  value = tonumber(value)
  if value == nil then return "--" end
  if value >= 1024 then
    return string.format("%.1f", value / 1024)
  end
  return Format.num(value, 0)
end

function Format.rate_unit(value)
  value = tonumber(value)
  if value and value >= 1024 then return "MB/s" end
  return "KB/s"
end

return Format
