-- WoWHU Probe: written to avoid Lua 5.1-only syntax (no '#', no '...', no string.match),
-- so it loads on either a Lua 5.0 or a Lua 5.1 client.
local G = getfenv(0)

local function count(t)
   local n = 0
   while t[n + 1] ~= nil do n = n + 1 end
   return n
end

local function say(msg)
   DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[probe]|r "..tostring(msg))
   if WoWHUProbeDB and WoWHUProbeDB.lines then
      WoWHUProbeDB.lines[count(WoWHUProbeDB.lines) + 1] = tostring(msg)
   end
end

local function report(title, total, missing, n)
   if n == 0 then
      say(title..": all "..total.." present")
   else
      say(title..": MISSING "..n.."/"..total.." -> "..missing)
   end
end

local function checkGlobals(title, names)
   local missing, n = "", 0
   for i = 1, count(names) do
      if G[names[i]] == nil then
         missing = missing..names[i].." "
         n = n + 1
      end
   end
   report(title, count(names), missing, n)
end

local function checkLib(title, libname, names)
   local lib = G[libname]
   local missing, n = "", 0
   for i = 1, count(names) do
      if type(lib) ~= "table" or lib[names[i]] == nil then
         missing = missing..libname.."."..names[i].." "
         n = n + 1
      end
   end
   report(title, count(names), missing, n)
end

local function checkMethods(title, obj, names)
   local missing, n = "", 0
   for i = 1, count(names) do
      if type(obj[names[i]]) ~= "function" then
         missing = missing..names[i].." "
         n = n + 1
      end
   end
   report(title, count(names), missing, n)
end

local fmod = math.fmod or math.mod
local function hash(text)
   if (not text) or string.len(text) == 0 then return 0 end
   local counter = 1
   local dlug = string.len(text)
   local i = 1
   while i <= dlug do
      counter = fmod(counter * 8161, 4294967279)
      counter = counter + string.byte(text, i) * 16776193
      counter = counter + (string.byte(text, i + 1) or (dlug - i + 256)) * 8372226
      counter = counter + (string.byte(text, i + 2) or (dlug - i + 256)) * 3932164
      i = i + 3
   end
   return fmod(counter, 4294967291)
end

local evtInfo, updInfo = nil, nil

local ef = CreateFrame("Frame")
ef:RegisterEvent("ADDON_LOADED")
ef:SetScript("OnEvent", function(a, b, c)
   if evtInfo then return end
   evtInfo = "params a="..tostring(a).." b="..tostring(b).." c="..tostring(c)
      .."  |  globals this="..tostring(G.this).." event="..tostring(G.event).." arg1="..tostring(G.arg1)
end)

local uf = CreateFrame("Frame")
uf:SetScript("OnUpdate", function(a)
   if updInfo then return end
   updInfo = "param a="..tostring(a).."  |  global arg1="..tostring(G.arg1)
   uf:SetScript("OnUpdate", nil)
end)

local function runProbe()
   WoWHUProbeDB = { lines = {} }
   local v, b, d, t = GetBuildInfo()
   say("---- WoWHU probe ----")
   say("_VERSION="..tostring(_VERSION).."  GetBuildInfo="..tostring(v).." / "..tostring(b).." / "..tostring(d).." / "..tostring(t))
   say("GetLocale="..tostring(GetLocale()))
   say("OnEvent convention: "..tostring(evtInfo))
   say("OnUpdate convention: "..tostring(updInfo))

   checkGlobals("lua/global funcs", { "select", "unpack", "strtrim", "strsplit", "wipe", "hooksecurefunc",
      "_G", "getglobal", "setglobal", "geterrorhandler", "mod", "getn", "tinsert", "tremove", "bit", "issecurevariable" })
   checkLib("string lib", "string", { "match", "gmatch", "gfind", "find", "gsub", "format", "byte", "reverse", "sub", "len" })
   checkLib("math/table lib", "math", { "fmod", "mod", "floor", "max", "min" })
   checkLib("table lib", "table", { "getn", "wipe", "sort", "insert", "remove", "maxn" })
   checkGlobals("retail APIs used by addon", { "C_Timer", "C_Map", "C_ChatInfo", "C_AddOns", "C_Item", "C_Spell",
      "Settings", "Mixin", "CreateFromMixin", "TooltipDataProcessor", "ChatFrame_AddMessageEventFilter",
      "IsInRaid", "IsInGuild", "UnitSex", "GetCursorPosition", "UIDropDownMenu_Initialize", "QuestInfo_Display",
      "LibStub" })

   local f = CreateFrame("Frame")
   local btn = CreateFrame("Button")
   local tex = f:CreateTexture()
   local fs = f:CreateFontString()
   checkMethods("Frame methods", f, { "HookScript", "GetScript", "SetScript", "SetSize", "SetBackdrop",
      "SetMovable", "RegisterForDrag", "SetScale", "GetEffectiveScale", "SetClampedToScreen", "CreateFontString", "GetChildren", "GetRegions" })
   checkMethods("Button methods", btn, { "GetFontString", "SetText", "SetNormalTexture", "Enable", "Disable" })
   checkMethods("Texture methods", tex, { "SetColorTexture", "SetDesaturated", "SetTexture", "SetTexCoord" })
   checkMethods("FontString methods", fs, { "SetFont", "GetFont", "SetJustifyH", "SetWidth", "SetText", "GetText" })

   checkGlobals("frames hooked in WoW_Core.lua", { "TutorialFrame", "PlayerChoiceFrame", "ItemTextFrame",
      "ItemTextNextPageButton", "ItemTextPrevPageButton", "StaticPopup1", "StaticPopup2", "GameMenuFrame",
      "MerchantFrame", "PVEFrame", "WorldMapFrame", "QuestScrollFrame", "CharacterFrame", "FriendsFrame",
      "HelpPlateTooltip", "SplashFrame", "PingSystemTutorialTitleText", "BankFrame", "ItemRefTooltip",
      "EventToastManagerFrame", "ReputationFrame", "AddonList", "MailFrame", "CommunitiesFrame",
      "SettingsPanel", "LFDRoleCheckPopup", "LFGDungeonReadyDialog", "ObjectiveTrackerFrame",
      "QuestFrame", "GossipFrame", "GameTooltip", "ShoppingTooltip1", "WOWBB1", "WOWTR" })
   checkGlobals("other frames used by WoW_Tooltips.lua", { "MacroFrame", "SpellBookFrame", "TalentFrame",
      "AuctionFrame", "TradeSkillFrame", "CraftFrame", "EncounterJournal", "ProfessionsFrame",
      "PlayerSpellsFrame", "AchievementFrame", "InspectFrame", "TaxiFrame", "QuestLogFrame" })

   if MerchantFrameTab1 then
      say("child access: MerchantFrameTab1.Text="..tostring(MerchantFrameTab1.Text)
         .."  global MerchantFrameTab1Text="..tostring(G.MerchantFrameTab1Text))
   else
      say("child access: MerchantFrameTab1 does not exist")
   end

   local tests = { "Cancel", "Accept", "Log Out" }
   for i = 1, count(tests) do
      local theirs = "n/a"
      if G.StringHash then theirs = G.StringHash(tests[i]) end
      say("hash('"..tests[i].."')  probe="..tostring(hash(tests[i])).."  addon StringHash="..tostring(theirs))
   end
   say("---- end ---- (saved)")
end

SLASH_WOWHUPROBE1 = "/wowhuprobe"
SlashCmdList["WOWHUPROBE"] = runProbe
