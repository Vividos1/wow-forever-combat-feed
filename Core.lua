-- Forever Combat Feed v0.5.0. A deliberately small, dependency-free Forever addon.
-- COMBAT_LOG_EVENT_UNFILTERED is not available to Forever addons.
local addonName, ns = ...
local A = {}; ns.Core = A
local floor, min, max = math.floor, math.min, math.max
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local defaults = {
  width = 360, height = 220, x = 0, y = 0, point = "CENTER",
  fontSize = 14, alpha = 0.35, hideDelay = 2, maxLines = 90,
  locked = false, spellGuess = true, showIcons = true, showSummary = true,
  summaryDuration = 9, showMinimap = true, minimapAngle = 315, minimapSquare = true,
  newestFirst = false, suppressBlizzardText = false,
  colors = {
    auto = {1,1,1}, crit = {1,1,1}, ability = {0.2,0.9,1}, abilityCrit = {0.2,0.9,1},
    incoming = {1,0.25,0.25}, incomingCrit = {1,0.25,0.25},
  },
}
A.defaults = defaults
local function deepCopy(source)
  local dest = {}
  for k,v in pairs(source) do dest[k] = type(v)=="table" and deepCopy(v) or v end
  return dest
end
local function mergeMissing(dest, source)
  for k,v in pairs(source) do
    if dest[k] == nil then dest[k]=type(v)=="table" and deepCopy(v) or v
    elseif type(v)=="table" and type(dest[k])=="table" then mergeMissing(dest[k],v) end
  end
end
local function safe(x) return not (issecretvalue and issecretvalue(x)) end
local events = CreateFrame("Frame")
local entries, rows = {}, {}
local lastSpell, lastSpellAt, lastSpellIcon
local combat = false
local fadeToken = 0
local preview = false
local scrollPos = 0
local rowHeight = 19
local summaryDamageDone, summaryDamageTaken = 0, 0
local completeDamageDone, completeDamageTaken = true, true
local previousCombatTextCVars = {}
local combatStartXP, combatStartXPMax, combatStartLevel
local killTarget, killedThisCombat
local summaryToken=0
local function safeNumber(value)
  return type(value)=="number" and (not issecretvalue or not issecretvalue(value))
end
local function safeString(value)
  return type(value)=="string" and (not issecretvalue or not issecretvalue(value))
end
local function unitNameSafe(unit)
  if not UnitExists(unit) then return nil end
  local name=UnitName(unit)
  if safeString(name) and name~="" then return name end
end
local function xpSnapshot()
  local lv=UnitLevel("player")
  local cur=UnitXP("player")
  local mx=UnitXPMax("player")
  if safeNumber(lv) and safeNumber(cur) and safeNumber(mx) then return lv,cur,mx end
end


local frame = CreateFrame("Frame", "ForeverCombatFeedWindow", UIParent, "BackdropTemplate")
frame:SetSize(360,220)
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:SetResizable(true)
frame:EnableMouse(true)
frame:SetResizeBounds(220,90,800,650)
frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=10, insets={left=3,right=3,top=3,bottom=3}})
frame:SetBackdropBorderColor(0.3,0.7,0.8,0.6)
frame:Hide()
A.frame=frame

local header=CreateFrame("Frame",nil,frame)
header:SetPoint("TOPLEFT",5,-3); header:SetPoint("TOPRIGHT",-5,-3);header:SetHeight(20)
header:EnableMouse(true);header:RegisterForDrag("LeftButton")
local title=header:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
title:SetPoint("LEFT",5,0);title:SetText("COMBAT FEED")
local gear=CreateFrame("Button",nil,header)
gear:SetSize(19,19);gear:SetPoint("RIGHT",-4,0)
gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
gear:SetScript("OnClick",function() if A.ToggleOptions then A.ToggleOptions() end end)
local lockButton=CreateFrame("Button",nil,header)
lockButton:SetSize(18,18);lockButton:SetPoint("RIGHT",gear,"LEFT",-5,0)
lockButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-LockButton-Up")
lockButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
local lockText=lockButton:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
lockText:SetPoint("CENTER",0,0)
lockButton:SetScript("OnClick",function()
  A.db.locked=not A.db.locked
  A.Refresh()
end)
header:SetScript("OnDragStart",function() if not A.db.locked then frame:StartMoving() end end)
header:SetScript("OnDragStop",function()
  frame:StopMovingOrSizing()
  local cx,cy=frame:GetCenter();local ux,uy=UIParent:GetCenter()
  if cx and ux then A.db.x=cx-ux;A.db.y=cy-uy end
end)

local resize=CreateFrame("Button",nil,frame)
resize:SetSize(18,18);resize:SetPoint("BOTTOMRIGHT",-1,1)
resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resize:RegisterForDrag("LeftButton")
resize:SetScript("OnDragStart",function() if not A.db.locked then frame:StartSizing("BOTTOMRIGHT") end end)
resize:SetScript("OnDragStop",function()
  frame:StopMovingOrSizing()
  A.db.width=floor(frame:GetWidth()+0.5);A.db.height=floor(frame:GetHeight()+0.5)
  A.Refresh()
end)

local scroll = CreateFrame("ScrollFrame",nil,frame)
scroll:SetPoint("TOPLEFT",9,-26);scroll:SetPoint("BOTTOMRIGHT",-14,10)
scroll:EnableMouseWheel(true)
local content=CreateFrame("Frame",nil,scroll)
content:SetWidth(330);content:SetHeight(100)
scroll:SetScrollChild(content)
local function makeRow(i)
  local r=CreateFrame("Frame",nil,content)
  r:SetHeight(rowHeight)
  r.value=r:CreateFontString(nil,"OVERLAY")
  r.value:SetPoint("LEFT",r,"LEFT",2,0)
  r.value:SetWidth(53) -- a fixed four-digit amount column
  r.value:SetJustifyH("RIGHT");r.value:SetWordWrap(false)
  r.icon=r:CreateTexture(nil,"ARTWORK")
  r.icon:SetSize(15,15);r.icon:SetPoint("LEFT",r.value,"RIGHT",7,0)
  r.name=r:CreateFontString(nil,"OVERLAY")
  r.name:SetPoint("LEFT",r.icon,"RIGHT",4,0)
  r.name:SetPoint("RIGHT",r,"RIGHT",-3,0)
  r.name:SetJustifyH("LEFT");r.name:SetWordWrap(false)
  rows[i]=r
  return r
end
local function applyRow(r,e,i)
  r:ClearAllPoints();r:SetPoint("TOPLEFT",content,"TOPLEFT",0,-(i-1)*rowHeight)
  r:SetPoint("RIGHT",content,"RIGHT",0,0)
  local style=e.style or "auto"
  local c=A.db.colors[style] or defaults.colors.auto
  local flags=(style=="crit" or style=="incomingCrit" or style=="abilityCrit") and "OUTLINE" or ""
  local sz=A.db.fontSize
  r.name:SetFont(FONT,sz,flags);r.value:SetFont(FONT,sz,flags)
  r.name:SetText(e.label or "Auto-Attack")
  -- amount can be a secret value. Never inspect, format, concatenate or compare it.
  r.value:SetText(e.amount)
  r.name:SetTextColor(c[1],c[2],c[3]);r.value:SetTextColor(c[1],c[2],c[3])
  if A.db.showIcons and e.icon then
    r.icon:SetTexture(e.icon);r.icon:Show();r.name:SetPoint("LEFT",r.icon,"RIGHT",4,0)
  else
    r.icon:Hide();r.name:SetPoint("LEFT",r.value,"RIGHT",7,0)
  end
  r:Show()
end
function A.Refresh()
  if not A.db then return end
  frame:SetBackdropColor(0.025,0.035,0.05,A.db.alpha)
  if A.RefreshMinimap then A.RefreshMinimap() end
  frame:SetBackdropBorderColor(0.3,0.7,0.8,A.db.alpha>0.12 and 0.55 or 0.25)
  title:Show()
  lockButton:Show()
  lockText:SetText(A.db.locked and "L" or "U")
  lockButton:SetAlpha(A.db.locked and 0.75 or 1)
  resize:SetShown(not A.db.locked)
  local needed=max(1,floor(scroll:GetHeight()/rowHeight))
  local maxOffset=max(0,#entries-needed)
  scrollPos=min(scrollPos,maxOffset)
  local first=max(1,#entries-needed+1-scrollPos)
  local visible=min(needed,#entries)
  content:SetWidth(max(160,scroll:GetWidth()));content:SetHeight(max(scroll:GetHeight(),needed*rowHeight))
  for i=1,needed do
    local r=rows[i] or makeRow(i)
    local e= A.db.newestFirst and entries[#entries-scrollPos-i+1] or entries[first+i-1]
    if e and i<=visible then applyRow(r,e,i) else r:Hide() end
  end
  for i=needed+1,#rows do rows[i]:Hide() end
end
scroll:SetScript("OnMouseWheel",function(_,delta)
  scrollPos=max(0,scrollPos+delta*3);A.Refresh()
end)
frame:SetScript("OnSizeChanged",function() if A.db then A.Refresh() end end)

local function append(label,amount,style,icon)
  -- Only the UI fontstring reads amount. We retain it in memory; never serialize combat entries.
  entries[#entries+1]={label=label,amount=amount,style=style,icon=icon}
  if #entries>A.db.maxLines then table.remove(entries,1) end
  scrollPos=0
  A.Refresh()
end
A.Append=append
-- Summary lives outside the scrolling frame, with its own visibility timer.
local summary=CreateFrame("Frame","ForeverCombatFeedSummary",UIParent,"BackdropTemplate")
summary:SetSize(360,115);summary:SetPoint("TOPLEFT",frame,"BOTTOMLEFT",0,-7)
summary:SetFrameStrata("MEDIUM")
summary:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=11,insets={left=3,right=3,top=3,bottom=3}})
summary:SetBackdropColor(0.025,0.035,0.05,0.8)
summary:SetBackdropBorderColor(0.6,0.53,0.28,0.75)
summary:Hide()
local heading=summary:CreateFontString(nil,"OVERLAY","GameFontNormal")
heading:SetPoint("TOPLEFT",summary,"TOPLEFT",12,-10)
heading:SetPoint("TOPRIGHT",summary,"TOPRIGHT",-32,-10)
heading:SetJustifyH("LEFT")
local close=CreateFrame("Button",nil,summary,"UIPanelCloseButton")
close:SetSize(24,24);close:SetPoint("TOPRIGHT",-3,-3)
close:SetScript("OnClick",function() summaryToken=summaryToken+1;summary:Hide() end)
local captions={"Encounter Damage Done:","Encounter Damage Taken:","Experience Earned:"}
local summaryValues={}
for i=1,3 do
  local y=-39-(i-1)*24
  local t=summary:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  t:SetPoint("TOPLEFT",12,y);t:SetWidth(215);t:SetJustifyH("LEFT");t:SetText(captions[i])
  local v=summary:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  v:SetPoint("TOPRIGHT",-14,y);v:SetWidth(125);v:SetJustifyH("RIGHT")
  summaryValues[i]=v
end
local function showSummary(target,done,taken,xp)
  if not A.db.showSummary then return end
  heading:SetText((target or "Combat")..(target and " Defeated" or " Summary"))
  summaryValues[1]:SetText(done);summaryValues[1]:SetTextColor(1,1,1)
  summaryValues[2]:SetText(taken);summaryValues[2]:SetTextColor(1,0.3,0.3)
  summaryValues[3]:SetText(xp);summaryValues[3]:SetTextColor(1,0.85,0.3)
  summary:SetWidth(frame:GetWidth())
  summary:Show()
  summaryToken=summaryToken+1
  local token=summaryToken
  C_Timer.After(A.db.summaryDuration,function()
    if token==summaryToken then summary:Hide() end
  end)
end
A.HideSummary=function() summaryToken=summaryToken+1;summary:Hide() end
A.PreviewSummary=function()
  showSummary("Young Wolf","437","8","40")
end

-- Minimap icon: drag around the minimap BORDER, rather than moving over its surface.
-- Works with both normal circular minimaps and square minimap skins.
local mini=CreateFrame("Button","ForeverCombatFeedMinimapButton",Minimap)
mini:SetSize(31,31)
mini:SetFrameStrata("MEDIUM");mini:SetFrameLevel(8)
mini:SetMovable(true)
mini:RegisterForClicks("LeftButtonUp","RightButtonUp")
mini:RegisterForDrag("LeftButton")
local border=mini:CreateTexture(nil,"OVERLAY")
border:SetPoint("TOPLEFT",mini,"TOPLEFT",0,0)
border:SetSize(53,53)
border:SetTexture(136430) -- standard LibDBIcon tracking border alignment
local iconBackground=mini:CreateTexture(nil,"BACKGROUND")
iconBackground:SetPoint("TOPLEFT",mini,"TOPLEFT",7,-5);iconBackground:SetSize(20,20)
iconBackground:SetTexture(136467) -- standard LibDBIcon minimap background
local miniIcon=mini:CreateTexture(nil,"ARTWORK")
miniIcon:SetTexture("Interface\\Icons\\Ability_Warrior_SavageBlow")
miniIcon:SetTexCoord(0.08,0.92,0.08,0.92)
miniIcon:SetSize(17,17);miniIcon:SetPoint("TOPLEFT",mini,"TOPLEFT",7,-6)
local miniDragging=false
local ignoreClick=false
local function squareMinimap()
  if A.db and A.db.minimapSquare ~= nil then return A.db.minimapSquare end
  -- A stock round minimap uses MinimapMask; common square skins replace it.
  if not Minimap.GetMaskTexture then return false end
  local mask=Minimap:GetMaskTexture()
  if type(mask)~="string" then return false end
  return not mask:lower():find("minimapmask",1,true)
end
local function positionMinimapButton()
  if not A.db then return end
  local angle=math.rad(A.db.minimapAngle or 315)
  local x,y=math.cos(angle),math.sin(angle)
  local halfW,halfH=Minimap:GetWidth()/2+5,Minimap:GetHeight()/2+5
  if squareMinimap() then
    -- Match LibDBIcon-1.0 SQUARE placement. The diagonal projection is
    -- clamped to each edge instead of intersecting a ray with the rectangle.
    local diagW=math.sqrt(2*halfW*halfW)-10
    local diagH=math.sqrt(2*halfH*halfH)-10
    x=max(-halfW,min(x*diagW,halfW))
    y=max(-halfH,min(y*diagH,halfH))
  else
    x,y=x*halfW,y*halfH
  end
  mini:ClearAllPoints()
  mini:SetPoint("CENTER",Minimap,"CENTER",x,y)
end
local function updateMinimapFromCursor()
  local mx,my=Minimap:GetCenter()
  local scale=Minimap:GetEffectiveScale()
  if not mx or not my or not scale or scale==0 then return end
  local cx,cy=GetCursorPosition()
  local dx,dy=cx/scale-mx,cy/scale-my
  if math.abs(dx)+math.abs(dy)<2 then return end
  local radians
  if math.atan2 then radians=math.atan2(dy,dx)
  elseif dx<0 then radians=math.atan(dy/dx)+math.pi
  elseif dx>0 then radians=math.atan(dy/dx)
  else radians=dy>=0 and math.pi/2 or -math.pi/2 end
  A.db.minimapAngle=(math.deg(radians)+360)%360
  positionMinimapButton()
end
mini:SetScript("OnDragStart",function()
  miniDragging=true
  ignoreClick=true
  mini:SetScript("OnUpdate",function() updateMinimapFromCursor() end)
end)
mini:SetScript("OnDragStop",function()
  updateMinimapFromCursor()
  miniDragging=false
  mini:SetScript("OnUpdate",nil)
end)
mini:SetScript("OnClick",function(_,button)
  if miniDragging or ignoreClick then ignoreClick=false;return end
  if button=="RightButton" then A.Preview() elseif A.ToggleOptions then A.ToggleOptions() end
end)
mini:SetScript("OnEnter",function(self)
  GameTooltip:SetOwner(self,"ANCHOR_LEFT")
  GameTooltip:AddLine("Forever Combat Feed")
  GameTooltip:AddLine("Left-click: movable settings",1,1,1)
  GameTooltip:AddLine("Right-click: feed preview",1,1,1)
  GameTooltip:AddLine("Drag: move around minimap edge",1,1,1)
  GameTooltip:Show()
end)
mini:SetScript("OnLeave",function() GameTooltip:Hide() end)
function A.RefreshMinimap()
  if A.db then mini:SetShown(A.db.showMinimap);positionMinimapButton() end
end

function A.Preview()
  preview=true;fadeToken=fadeToken+1;frame:Show()
  entries={}
  append("Auto-Attack",123,"auto")
  append("Auto-Attack",438,"crit")
  append("Judgement",267,"ability",135959)
  append("Seal of Righteousness",103,"ability",132325)
  append("Young Wolf",62,"incoming")
  append("Young Wolf",211,"incomingCrit")
end
function A.ClosePreview()
  preview=false
  if not combat then frame:Hide() end
end
local function startCombat()
  combat=true;preview=false;fadeToken=fadeToken+1
  entries={};scrollPos=0
  summaryDamageDone,summaryDamageTaken=0,0
  completeDamageDone,completeDamageTaken=true,true
  combatStartLevel,combatStartXP,combatStartXPMax=xpSnapshot()
  killTarget=unitNameSafe("target")
  killedThisCombat=false
  A.HideSummary()
  frame:Show();A.Refresh()
end
-- Server-owned encounter totals are available once combat ends. Avoid using
-- UNIT_COMBAT values for arithmetic; these are often secret in Forever.
local function encounterTotal(meterType)
  if not C_DamageMeter or not C_DamageMeter.GetCombatSessionFromType then return nil end
  local current=Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current or 1
  local ok,session=pcall(C_DamageMeter.GetCombatSessionFromType,current,meterType)
  if not ok or not session or not session.combatSources then return nil end
  for _,source in ipairs(session.combatSources) do
    -- isLocalPlayer is documented NeverSecret and filters out other players.
    if source.isLocalPlayer then
      local n=source.totalAmount
      if safeNumber(n) then return math.floor(n+0.5) end
      return nil
    end
  end
  return 0
end
local function stopCombat()
  combat=false;fadeToken=fadeToken+1
  -- PARTY_KILL may not fire for every kill; check dead target as fallback.
  if not killedThisCombat and UnitExists("target") then
    local dead=UnitIsDead("target")
    if safe(dead) and dead then
      killedThisCombat=true
      killTarget=unitNameSafe("target") or killTarget
    end
  end
  local token=fadeToken
  C_Timer.After(A.db.hideDelay,function()
    if not combat and not preview and fadeToken==token then frame:Hide() end
  end)
  if not killedThisCombat or not A.db.showSummary then return end
  -- Give the built-in meter and XP reward a moment to settle.
  C_Timer.After(0.4,function()
    if combat or fadeToken~=token then return end
    local dm=Enum and Enum.DamageMeterType
    local done=encounterTotal(dm and dm.DamageDone or 0)
    local taken=encounterTotal(dm and dm.DamageTaken or 7)
    local lv,cur,mx=xpSnapshot()
    local xp="Unavailable"
    if lv and combatStartLevel and lv==combatStartLevel and combatStartXPMax==mx then
      xp=tostring(math.max(0,cur-combatStartXP))
    elseif lv and combatStartLevel and lv>combatStartLevel then
      xp="Leveled up"
    end
    showSummary(killTarget,done and tostring(done) or "Unavailable",taken and tostring(taken) or "Unavailable",xp)
  end)
end
-- Optionally suppress the built-in overhead damage numbers. Restore original
-- CVar states when disabled or on logout, never force other addon's text.
local cvarNames={"floatingCombatTextCombatDamage_v2","floatingCombatTextCombatDamage", "floatingCombatTextCombatHealing_v2", "floatingCombatTextCombatHealing"}
function A.UpdateFloatingCombatText()
  if not C_CVar or not C_CVar.GetCVar or not C_CVar.SetCVar then return end
  for _,key in ipairs(cvarNames) do
    if A.db.suppressBlizzardText then
      local ok,v=pcall(C_CVar.GetCVar,key)
      if ok and v~=nil and previousCombatTextCVars[key]==nil then previousCombatTextCVars[key]=v end
      if ok and v~=nil then pcall(C_CVar.SetCVar,key,"0") end
    elseif previousCombatTextCVars[key]~=nil then
      pcall(C_CVar.SetCVar,key,previousCombatTextCVars[key])
      previousCombatTextCVars[key]=nil
    end
  end
end
local function isCrit(flag)
  if not safe(flag) then return false end
  return flag=="CRITICAL"
end
local function currentSpellLabel()
  if not A.db.spellGuess or not lastSpell or (GetTime()-lastSpellAt)>1.0 then return nil,nil end
  return lastSpell,lastSpellIcon
end
-- UNIT_COMBAT supplies the victim, not the attacker. With only one visible
-- hostile combatant we can make a useful best-effort label. With several,
-- attribution is ambiguous and must not be invented.
local function inferredAttackerName()
  local uniqueName, hostileCount=nil,0
  for i=1,40 do
    local unit="nameplate"..i
    if UnitExists(unit) and UnitCanAttack("player",unit) then
      local fighting=UnitAffectingCombat(unit)
      if safe(fighting) and fighting then
        local name=unitNameSafe(unit)
        if name then
          hostileCount=hostileCount+1
          if hostileCount>1 then return "Unknown attacker" end
          uniqueName=name
        end
      end
    end
  end
  if hostileCount==1 then return uniqueName end
  if hostileCount==0 then
    -- If no enemy nameplates are accessible, use the player's hostile target
    -- as a tentative fallback, just as the first working build did.
    if UnitExists("target") and UnitCanAttack("player","target") then
      local fighting=UnitAffectingCombat("target")
      if safe(fighting) and fighting then
        return unitNameSafe("target") or "Unknown attacker"
      end
    end
  end
  return "Unknown attacker"
end
local function onUnitCombat(unit,action,flag,amount,school)
  if not combat then return end
  if not safe(unit) or not safe(action) or not safe(flag) then return end
  if action~="WOUND" and action~="DAMAGE" then return end
  if unit=="player" then
    -- The current target is a possible attacker, not a guaranteed source.
    append(inferredAttackerName(),amount,isCrit(flag) and "incomingCrit" or "incoming")
    if safeNumber(amount) then summaryDamageTaken=summaryDamageTaken+amount
    else completeDamageTaken=false end
  elseif unit=="target" then
    -- UNIT_COMBAT describes the VICTIM; it cannot reliably identify the source.
    -- A hit on your target may instead belong to another player or your pet.
    local name,icon=currentSpellLabel()
    local ability=name or (safe(school) and school~=1 and "Spell" or nil)
    append(ability or "Auto-Attack",amount,ability and (isCrit(flag) and "abilityCrit" or "ability") or (isCrit(flag) and "crit" or "auto"),icon)
    if safeNumber(amount) then summaryDamageDone=summaryDamageDone+amount
    else completeDamageDone=false end
  end
end
local function onSpellSucceeded(unit,castGUID,spellID)
  if unit~="player" or not safe(spellID) or not C_Spell or not C_Spell.GetSpellInfo then return end
  local info=C_Spell.GetSpellInfo(spellID)
  if info and safe(info.name) then
    lastSpell=info.name;lastSpellIcon=info.iconID;lastSpellAt=GetTime()
  end
end
local function onEvent(_,event,...)
  if event=="ADDON_LOADED" then
    local loaded=...
    if loaded~=addonName then return end
    if type(ForeverCombatFeedDB)~="table" then ForeverCombatFeedDB={} end
    mergeMissing(ForeverCombatFeedDB,defaults)
    A.db=ForeverCombatFeedDB
    frame:SetSize(A.db.width,A.db.height)
    frame:ClearAllPoints();frame:SetPoint("CENTER",UIParent,"CENTER",A.db.x,A.db.y)
    A.Refresh()
    A.RefreshMinimap()
    A.UpdateFloatingCombatText()
    if A.InitializeOptions then A.InitializeOptions() end
    if UnitAffectingCombat("player") then startCombat() end
  elseif event=="PLAYER_LOGOUT" then
    if A.db and A.db.suppressBlizzardText then
      A.db.suppressBlizzardText=false; A.UpdateFloatingCombatText(); A.db.suppressBlizzardText=true
    end
  elseif event=="PLAYER_REGEN_DISABLED" then startCombat()
  elseif event=="PLAYER_REGEN_ENABLED" then stopCombat()
  elseif event=="UNIT_COMBAT" then onUnitCombat(...)
  elseif event=="UNIT_SPELLCAST_SUCCEEDED" then onSpellSucceeded(...)
  elseif event=="PARTY_KILL" then
    killedThisCombat=true
    killTarget=unitNameSafe("target") or killTarget
  elseif event=="PLAYER_TARGET_CHANGED" then
    if combat and not killedThisCombat then killTarget=unitNameSafe("target") or killTarget end
  end
end
events:SetScript("OnEvent",onEvent)
for _,e in ipairs({"ADDON_LOADED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","UNIT_COMBAT","UNIT_SPELLCAST_SUCCEEDED","PARTY_KILL","PLAYER_TARGET_CHANGED","PLAYER_LOGOUT"}) do events:RegisterEvent(e) end
SLASH_FOREVERCOMBATFEED1="/fcf"
SLASH_FOREVERCOMBATFEED2="/combatfeed"
SlashCmdList.FOREVERCOMBATFEED=function(msg)
  msg=(msg or ""):lower():match("^%s*(.-)%s*$")
  if msg=="test" or msg=="preview" or msg=="move" then A.Preview()
  elseif msg=="hide" then A.ClosePreview()
  elseif msg=="lock" then A.db.locked=true;A.Refresh()
  elseif msg=="unlock" then A.db.locked=false;A.Preview()
  else if A.ToggleOptions then A.ToggleOptions() end end
end
