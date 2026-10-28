-- FlightTimes (WoW 1.12 / Octowow)

local DB
local trip, curName, curCont

local function Msg(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccFlightTimes|r: " .. text)
end

local function Fmt(s)
  s = math.floor(s + 0.5)
  local m = math.floor(s / 60)
  return m .. ":" .. string.format("%02d", s - m * 60)
end

local function MapSize()
  local f = getglobal("TaxiRouteMap")
  if f and f.GetWidth and f:GetWidth() > 0 then
    return f:GetWidth(), f:GetHeight()
  end
  return 1, 1
end

local function CurrentIndex()
  for i = 1, NumTaxiNodes() do
    if TaxiNodeGetType(i) == "CURRENT" then return i end
  end
  return nil
end

-- length of whole route to node
local function RouteDistance(i)
  local w, h = MapSize()
  local total = 0
  local hops = 0
  if GetNumRoutes then hops = GetNumRoutes(i) or 0 end

  if hops > 0 and TaxiGetSrcX and TaxiGetDestX then
    for r = 1, hops do
      local dx = (TaxiGetDestX(i, r) - TaxiGetSrcX(i, r)) * w
      local dy = (TaxiGetDestY(i, r) - TaxiGetSrcY(i, r)) * h
      total = total + math.sqrt(dx * dx + dy * dy)
    end
  else
    -- fallback
    local ci = CurrentIndex()
    if ci then
      local x1, y1 = TaxiNodePosition(ci)
      local x2, y2 = TaxiNodePosition(i)
      local dx = (x2 - x1) * w
      local dy = (y2 - y1) * h
      total = math.sqrt(dx * dx + dy * dy)
    end
  end
  return total
end

local function Median(t)
  table.sort(t)
  local n = table.getn(t)
  if n == 0 then return nil end
  local m = math.floor(n / 2)
  if m * 2 == n then return (t[m] + t[m + 1]) / 2 end
  return t[m + 1]
end

local function Lookup(src, dst)
  local key = src .. ">" .. dst
  local rkey = dst .. ">" .. src
  local shipped = FlightTimesData or {}

  local t = shipped[key]
  if t then return t, "database" end
  t = DB.exact[key]
  if t then return t, "learned" end
  t = shipped[rkey]
  if t then return t, "database, reverse" end
  t = DB.exact[rkey]
  if t then return t, "learned, reverse" end
  return nil
end

local function Estimate(src, dst, dist, cont)
  if not DB or not src or not dst then return nil end

  local t, how = Lookup(src, dst)
  if t then return t, how end

  local s = DB.samples[cont or "?"]
  if s and dist and dist > 0 then
    local ratios = {}
    for i = 1, table.getn(s) do
      if s[i].d > 0 then table.insert(ratios, s[i].t / s[i].d) end
    end
    local k = Median(ratios)
    if k then return dist * k, "estimate" end
  end
  return nil
end


-- Tooltip
local origEnter = TaxiNodeOnButtonEnter
if origEnter then
  TaxiNodeOnButtonEnter = function(button)
    origEnter(button)
    local b = button or this
    if not b or not DB then return end

    local i = b:GetID()
    if TaxiNodeGetType(i) ~= "REACHABLE" then return end

    local src = curName
    if not src then
      local ci = CurrentIndex()
      if ci then src = TaxiNodeName(ci) end
    end

    local secs, how = Estimate(src, TaxiNodeName(i), RouteDistance(i), curCont)
    if secs then
      local pre = ""
      if how == "estimate" then pre = "~" end
      GameTooltip:AddLine("Flight time: " .. pre .. Fmt(secs) .. " (" .. how .. ")", 0.4, 1, 0.8)
    else
      GameTooltip:AddLine("Flight time: unknown, fly once to calibrate", 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
  end
end


-- Learn flight times
local origTake = TakeTaxiNode
TakeTaxiNode = function(index)
  if DB then
    local dst = TaxiNodeName(index)
    local dist = RouteDistance(index)
    trip = {
      src = curName,
      dst = dst,
      dist = dist,
      cont = curCont or "?",
      predicted = Estimate(curName, dst, dist, curCont),
      t0 = GetTime(),
    }
  end
  origTake(index)
end

local function FinishTrip(secs)
  if secs < 5 or not trip.src or not trip.dst then return end

  DB.exact[trip.src .. ">" .. trip.dst] = math.floor(secs + 0.5)

  if trip.dist and trip.dist > 0 then
    DB.samples[trip.cont] = DB.samples[trip.cont] or {}
    local s = DB.samples[trip.cont]
    table.insert(s, { d = trip.dist, t = secs })
    while table.getn(s) > 40 do table.remove(s, 1) end
  end

  Msg("recorded " .. trip.src .. " -> " .. trip.dst .. ": " .. Fmt(secs))
end

-- Countdown bar while flying

local bar = CreateFrame("StatusBar", "FlightTimesBar", UIParent)
bar:SetWidth(240)
bar:SetHeight(18)
bar:SetPoint("TOP", UIParent, "TOP", 0, -120)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetStatusBarColor(0.2, 0.8, 0.7)
bar:SetMinMaxValues(0, 1)
bar:SetValue(0)
bar:SetMovable(true)
bar:EnableMouse(true)
bar:RegisterForDrag("LeftButton")
bar:SetScript("OnDragStart", function() this:StartMoving() end)
bar:SetScript("OnDragStop", function()
  this:StopMovingOrSizing()
  if DB then
    local x, y = this:GetCenter()
    DB.pos = { x = x, y = y }
  end
end)

local barbg = bar:CreateTexture(nil, "BACKGROUND")
barbg:SetAllPoints(bar)
barbg:SetTexture(0, 0, 0, 0.5)

bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
bar:Hide()

local function UpdateBar()
  local elapsed = GetTime() - trip.started
  if trip.predicted and trip.predicted > 0 then
    local left = trip.predicted - elapsed
    bar:SetMinMaxValues(0, trip.predicted)
    bar:SetValue(math.min(elapsed, trip.predicted))
    if left > 0 then
      bar.text:SetText(trip.dst .. "  " .. Fmt(left) .. " left")
    else
      bar.text:SetText(trip.dst .. "  arriving...")
    end
  else
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar.text:SetText(trip.dst .. "  " .. Fmt(elapsed) .. " elapsed")
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("TAXIMAP_OPENED")

f:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    FlightTimesDB = FlightTimesDB or {}
    DB = FlightTimesDB
    DB.exact = DB.exact or {}
    DB.samples = DB.samples or {}
    if DB.pos then
      bar:ClearAllPoints()
      bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", DB.pos.x, DB.pos.y)
    end

  elseif event == "TAXIMAP_OPENED" and DB then
    local ci = CurrentIndex()
    curName = nil
    if ci then curName = TaxiNodeName(ci) end

    curCont = "?"
    if not (WorldMapFrame and WorldMapFrame:IsVisible()) then
      SetMapToCurrentZone()
      curCont = GetCurrentMapContinent()
    end

    local list = {}
    for i = 1, NumTaxiNodes() do
      if TaxiNodeGetType(i) == "REACHABLE" then
        table.insert(list, { name = TaxiNodeName(i), dist = RouteDistance(i) })
      end
    end
    DB.last = { origin = curName, cont = curCont, list = list }
  end
end)

f:SetScript("OnUpdate", function()
  if not trip then return end
  local onTaxi = UnitOnTaxi("player")

  if not trip.started then
    if onTaxi then
      trip.started = GetTime()
      trip.lastbar = 0
      bar:Show()
      UpdateBar()
    elseif GetTime() - trip.t0 > 20 then
      trip = nil
    end
  elseif not onTaxi then
    bar:Hide()
    FinishTrip(GetTime() - trip.started)
    trip = nil
  elseif GetTime() - trip.lastbar > 0.2 then
    trip.lastbar = GetTime()
    UpdateBar()
  end
end)

-- commands: /ft  /ft known  /ft reset  /ft debug

SLASH_FLIGHTTIMES1 = "/ft"
SLASH_FLIGHTTIMES2 = "/flighttimes"

SlashCmdList["FLIGHTTIMES"] = function(msg)
  if not DB then return end
  msg = string.lower(msg or "")

  if msg == "reset" then
    DB.exact = {}
    DB.samples = {}
    Msg("all flight times cleared")

  elseif msg == "debug" then
    Msg("GetNumRoutes: " .. tostring(GetNumRoutes ~= nil))
    Msg("TaxiGetSrcX: " .. tostring(TaxiGetSrcX ~= nil))
    Msg("TaxiNodeOnButtonEnter: " .. tostring(TaxiNodeOnButtonEnter ~= nil))
    Msg("TaxiRouteMap: " .. tostring(getglobal("TaxiRouteMap") ~= nil))

  elseif msg == "stats" then
    local nd, nl, nnew = 0, 0, 0
    local shipped = FlightTimesData or {}
    for _ in pairs(shipped) do nd = nd + 1 end
    for route in pairs(DB.exact) do
      nl = nl + 1
      if not shipped[route] then nnew = nnew + 1 end
    end
    Msg(nd .. " routes in database, " .. nl .. " learned (" .. nnew .. " not in database yet)")

  elseif msg == "known" then
    local list = {}
    local seen = {}
    for route, secs in pairs(FlightTimesData or {}) do
      seen[route] = 1
      table.insert(list, { name = route, secs = secs, tag = "database" })
    end
    for route, secs in pairs(DB.exact) do
      if not seen[route] then
        table.insert(list, { name = route, secs = secs, tag = "learned" })
      end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    if table.getn(list) == 0 then
      Msg("nothing yet, fly somewhere")
      return
    end
    for i = 1, table.getn(list) do
      Msg(list[i].name .. "  " .. Fmt(list[i].secs) .. "  [" .. list[i].tag .. "]")
    end

  else
    if not DB.last or not DB.last.list then
      Msg("open a flight master once first")
      return
    end
    local list = {}
    for i = 1, table.getn(DB.last.list) do
      local n = DB.last.list[i]
      local secs, how = Estimate(DB.last.origin, n.name, n.dist, DB.last.cont)
      table.insert(list, { name = n.name, secs = secs, how = how })
    end
    table.sort(list, function(a, b)
      if a.secs and b.secs then return a.secs < b.secs end
      if a.secs then return true end
      return false
    end)

    Msg("from " .. tostring(DB.last.origin))
    for i = 1, table.getn(list) do
      local e = list[i]
      if e.secs then
        local pre = ""
        if e.how == "estimate" then pre = "~" end
        Msg(e.name .. "  " .. pre .. Fmt(e.secs))
      else
        Msg(e.name .. "  unknown")
      end
    end
  end
end
