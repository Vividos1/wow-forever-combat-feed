local _,ns=...
local A=ns.Core
local options, settingsPanel
local function text(parent,value,x,y,font)
  local fs=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT",x,y);fs:SetText(value)
  return fs
end
local function button(parent,label,x,y,w,fn)
  local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
  b:SetSize(w or 96,24);b:SetPoint("TOPLEFT",x,y);b:SetText(label);b:SetScript("OnClick",fn)
  return b
end
local function slider(parent,label,x,y,minValue,maxValue,step,key,format)
  text(parent,label,x,y)
  local s=CreateFrame("Slider",nil,parent,"OptionsSliderTemplate")
  s:SetPoint("TOPLEFT",x+8,y-26);s:SetSize(300,16)
  s:SetMinMaxValues(minValue,maxValue);s:SetValueStep(step);s:SetObeyStepOnDrag(true)
  s:SetValue(A.db[key]);s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  local value=text(parent,"",x+336,y-24)
  local function update(n)
    n=math.floor(n/step+0.5)*step
    A.db[key]=n
    if key=="fontSize" or key=="alpha" then A.Refresh() end
    value:SetText(format and string.format(format,n) or tostring(n))
  end
  s:SetScript("OnValueChanged",function(_,n) update(n) end)
  update(A.db[key])
end
local function check(parent,label,x,y,key,fn)
  local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate")
  b:SetPoint("TOPLEFT",x,y);b:SetSize(25,25);b:SetChecked(A.db[key])
  local t=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  t:SetPoint("LEFT",b,"RIGHT",2,0);t:SetText(label)
  b:SetScript("OnClick",function(self)
    A.db[key]=not not self:GetChecked()
    if fn then fn() end
  end)
  return b
end
local function colorButton(parent,label,x,y,key)
  local t=text(parent,label,x,y)
  t:SetWidth(127);t:SetWordWrap(false)
  local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
  b:SetPoint("TOPLEFT",x+133,y+5);b:SetSize(74,20);b:SetText("Color")
  b:SetScript("OnClick",function()
    local c=A.db.colors[key]
    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
    ColorPickerFrame:SetupColorPickerAndShow({
      r=c[1],g=c[2],b=c[3],hasOpacity=false,
      swatchFunc=function()
        local r,g,b=ColorPickerFrame:GetColorRGB()
        c[1],c[2],c[3]=r,g,b
        if key=="ability" then A.db.colors.abilityCrit={r,g,b} end
        A.Refresh()
      end,
      cancelFunc=function(previous)
        if previous then c[1],c[2],c[3]=previous.r,previous.g,previous.b end
        A.Refresh()
      end,
    })
  end)
end
function A.InitializeOptions()
  if options then return end
  options=CreateFrame("Frame","ForeverCombatFeedOptions",UIParent,"BackdropTemplate")
  options:SetSize(565,718);options:SetPoint("CENTER",UIParent,"CENTER",-170,0)
  options:SetFrameStrata("DIALOG")
  options:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24,insets={left=6,right=6,top=6,bottom=6}})
  options:Hide();options:EnableMouse(true);options:SetMovable(true);options:SetClampedToScreen(true)
  options:RegisterForDrag("LeftButton")
  options:SetScript("OnDragStart",function(self) self:StartMoving() end)
  options:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
  text(options,"Forever Combat Feed — Settings",24,-20,"GameFontNormalLarge")
  text(options,"Drag the background to move settings while previewing",24,-45,"GameFontDisableSmall")
  button(options,"X",510,-14,30,function() options:Hide();A.ClosePreview() end)
  slider(options,"Font size",26,-75,10,28,1,"fontSize","%d pt")
  slider(options,"Background opacity",26,-144,0,0.9,0.05,"alpha","%.2f")
  slider(options,"Hide after combat",26,-213,0,15,0.5,"hideDelay","%.1f sec")
  check(options,"Guess spell names from recent casts (approximate)",26,-279,"spellGuess")
  check(options,"Show spell icons when available",26,-306,"showIcons",A.Refresh)
  check(options,"Show defeated-target summary",26,-333,"showSummary",function()
    if not A.db.showSummary then A.HideSummary() end
  end)
  check(options,"Show minimap button",26,-360,"showMinimap",A.RefreshMinimap)
  check(options,"Square minimap border",270,-360,"minimapSquare",A.RefreshMinimap)
  check(options,"Newest damage at top (top-down)",26,-387,"newestFirst",A.Refresh)
  check(options,"Hide Blizzard's floating damage/healing text",26,-414,"suppressBlizzardText",A.UpdateFloatingCombatText)
  slider(options,"Summary duration",26,-450,2,30,1,"summaryDuration","%d sec")
  text(options,"Damage colors",26,-517,"GameFontNormal")
  colorButton(options,"Auto attacks",26,-543,"auto")
  colorButton(options,"Auto crits",292,-543,"crit")
  colorButton(options,"Abilities",26,-574,"ability")
  colorButton(options,"Incoming hits",292,-574,"incoming")
  colorButton(options,"Incoming crits",26,-605,"incomingCrit")
  button(options,"Test summary",292,-600,190,function() A.PreviewSummary() end)
  button(options,"Preview / move",26,-655,157,function() A.Preview() end)
  button(options,"Hide preview",198,-655,143,function() A.ClosePreview() end)
  button(options,"Reset position",356,-655,176,function()
    A.db.x=0;A.db.y=0
    A.frame:ClearAllPoints();A.frame:SetPoint("CENTER",UIParent,"CENTER")
    A.Preview()
  end)
  settingsPanel=CreateFrame("Frame","ForeverCombatFeedSettingsLauncher",UIParent)
  settingsPanel.name="Forever Combat Feed"
  local info=settingsPanel:CreateFontString(nil,"ARTWORK","GameFontHighlight")
  info:SetPoint("TOPLEFT",20,-25)
  info:SetText("Forever Combat Feed has movable settings. Open them with the button below.")
  button(settingsPanel,"Open movable settings",20,-85,190,function() A.OpenOptions() end)
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category=Settings.RegisterCanvasLayoutCategory(settingsPanel,"Forever Combat Feed")
    Settings.RegisterAddOnCategory(category);A.settingsCategory=category
  elseif InterfaceOptions_AddCategory then InterfaceOptions_AddCategory(settingsPanel) end
end
function A.OpenOptions()
  if not options then A.InitializeOptions() end
  if Settings and SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
  options:Show();options:Raise();A.Preview()
end
function A.ToggleOptions()
  if not options then A.InitializeOptions() end
  if options:IsShown() then options:Hide();A.ClosePreview() else A.OpenOptions() end
end
