local MicTap = {}

-- 16 kHz I2S; take the largest sample-to-sample change in each 10 ms window.
-- On the test unit the weakest tap was 7363; the loudest other sound was 1535.
local SAMPLES_PER_BIN = 160
local IMPULSE_FLOOR = 800
local TAP_PEAK = 1200
local MIN_GAP_MS = 180
local MAX_GAP_MS = 550
local abs, max, byte = math.abs, math.max, string.byte

function MicTap.start(on_double, on_error, on_triple)
  if not (i2s and i2s.start and i2s.read and i2s.stop and tmr and tmr.create and millis) then
    return nil, "microphone API unavailable"
  end

  local timer, opened, last_read, warm_until
  local prev, samples, peak, audio_ms = nil, 0, 0, 0
  local impulse, last_tap_ms, tap_count

  local function clear_taps()
    last_tap_ms, tap_count = nil, 0
  end

  local function expire_pair(t)
    if tap_count ~= 2 or t - last_tap_ms <= MAX_GAP_MS then return end
    -- A third impulse can start on the last bin of the window. Let it finish
    -- (including the quiet tail) before deciding whether this was a double.
    if impulse and impulse.first - last_tap_ms <= MAX_GAP_MS and impulse.last - impulse.first < 100 then return end
    clear_taps()
    on_double()
  end

  local function accept_tap(t)
    local gap = last_tap_ms and t - last_tap_ms
    if not gap or gap > MAX_GAP_MS then
      if tap_count == 2 then on_double() end
      last_tap_ms, tap_count = t, 1
    elseif gap >= MIN_GAP_MS then
      if not on_triple then
        clear_taps()
        on_double()
      elseif tap_count == 2 then
        clear_taps()
        on_triple()
      else
        last_tap_ms, tap_count = t, 2
      end
    end
  end

  local function stop()
    if timer then
      pcall(timer.unregister, timer)
      timer = nil
    end
    if opened then
      opened = false
      pcall(i2s.stop, 0)
    end
  end

  local function finish_bin()
    local t, level = audio_ms, peak
    audio_ms, samples, peak = audio_ms + 10, 0, 0
    if level >= IMPULSE_FLOOR then
      if not impulse then
        impulse = { first = t, last = t, at = t, peak = level }
      else
        impulse.last = t
        if level > impulse.peak then impulse.at, impulse.peak = t, level end
      end
    elseif impulse and t - impulse.last > 60 then
      local event = impulse
      impulse = nil
      if event.peak >= TAP_PEAK then
        if event.last - event.first + 10 > 100 then clear_taps()
        else accept_tap(event.at) end
      end
    end
    if on_triple then expire_pair(t) end
  end

  local function feed(raw)
    -- The microphone packs signed 16-bit samples into the upper I2S bytes.
    for i = 3, #raw - 1, 4 do
      local lo, hi = byte(raw, i, i + 1)
      local value = lo + 256 * hi
      if value >= 32768 then value = value - 65536 end
      if prev then peak = max(peak, abs(value - prev)) end
      prev, samples = value, samples + 1
      if samples == SAMPLES_PER_BIN then finish_bin() end
    end
  end

  local function poll()
    if not opened then return end
    if app and app.exiting and app.exiting() then stop(); return end
    local now = millis()
    if now - last_read >= 150 then
      -- Do not join two taps across an interruption in the audio stream.
      prev, samples, peak, audio_ms = nil, 0, 0, 0
      impulse = nil
      clear_taps()
    end
    for _ = 1, 4 do
      local raw = i2s.read(0, 1024, 1)
      if type(raw) ~= "string" or #raw == 0 then break end
      if #raw % 4 ~= 0 then error("unaligned I2S samples") end
      last_read = now
      if now >= warm_until then feed(raw) end
    end
  end

  local ok, err = pcall(function()
    local started, reason = i2s.start(0, {
      mode = i2s.MODE_MASTER | i2s.MODE_RX,
      rate = 16000, bits = 32, channel = i2s.CHANNEL_ONLY_LEFT,
      format = i2s.FORMAT_I2S, buffer_count = 6, buffer_len = 512,
    })
    if started == false or reason then error(reason or "I2S start failed") end
    opened = true
    last_read = millis()
    warm_until = last_read + 400
    timer = tmr.create()
    local alarm_ok = timer:alarm(12, tmr.ALARM_AUTO, function()
      local polled, why = pcall(poll)
      if not polled then
        stop()
        if on_error then on_error(why) end
      end
    end)
    if alarm_ok == false then error("microphone timer failed") end
  end)
  if not ok then
    stop()
    return nil, err
  end
  return stop
end

return MicTap
