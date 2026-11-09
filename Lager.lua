-- Forever Harvest: Sammelmaterialien aller Charaktere (Taschen und Bank) und Tooltips.
local _, FG = ...
local La = FG:Modul("Lager")
local F = FG.Fundorte
local L = FG.L

local TASCHEN = { 0, 1, 2, 3, 4 }
local function BankTaschen()
  local liste = { -1 }
  local erste = (NUM_BAG_SLOTS or 4) + 1
  for i = erste, erste + (NUM_BANKBAGSLOTS or 6) - 1 do liste[#liste + 1] = i end
  if REAGENTBANK_CONTAINER then liste[#liste + 1] = REAGENTBANK_CONTAINER end
  return liste
end

local function Plaetze(tasche)
  if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(tasche) or 0 end
  return GetContainerNumSlots and GetContainerNumSlots(tasche) or 0
end

local function Inhalt(tasche, platz)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(tasche, platz)
    if info then return info.itemID, info.stackCount end
    return
  end
  if GetContainerItemInfo then
    local _, menge, _, _, _, _, _, _, _, id = GetContainerItemInfo(tasche, platz)
    return id, menge
  end
end

-- Zählt, was als Sammelmaterial gilt: alles aus der Materialliste und Beute gelernter Vorkommen.
local function IstMaterial(item)
  if FG.MATERIALIEN[item] then return true end
  for _, t in pairs(FG.root.typen) do if t.item == item then return true end end
  return false
end

local function Zaehlen(taschen)
  local summe = {}
  for _, tasche in ipairs(taschen) do
    for platz = 1, Plaetze(tasche) do
      local id, menge = Inhalt(tasche, platz)
      if id and IstMaterial(id) then summe[id] = (summe[id] or 0) + (menge or 1) end
    end
  end
  return summe
end

function La:Eigener()
  local key = FG:CharKey()
  local c = FG.root.charaktere[key]
  if not c then
    c = { taschen = {}, bank = {} }
    FG.root.charaktere[key] = c
  end
  if not c.klasse then
    local _, klasse = UnitClass("player")
    c.klasse = klasse
    c.fraktion = UnitFactionGroup and UnitFactionGroup("player") or nil
  end
  return c, key
end

function La:TaschenLesen()
  local c = self:Eigener()
  c.taschen = Zaehlen(TASCHEN)
  c.zeit = time()
  FG:Rufe("lager")
end

function La:BankLesen()
  local c = self:Eigener()
  c.bank = Zaehlen(BankTaschen())
  c.bankZeit = time()
  FG:Rufe("lager")
end

-- Bestand eines Materials: Summe und Liste { name, taschen, bank, eigener }.
function La:Bestand(item)
  local summe, liste = 0, {}
  local ich = FG:CharKey()
  for key, c in pairs(FG.root.charaktere) do
    local t, b = (c.taschen or {})[item] or 0, (c.bank or {})[item] or 0
    if t + b > 0 then
      summe = summe + t + b
      liste[#liste + 1] = { name = key:match("^[^-]+") or key, key = key, klasse = c.klasse, taschen = t, bank = b, eigener = key == ich }
    end
  end
  table.sort(liste, function(a, b)
    if a.eigener ~= b.eigener then return a.eigener end
    return (a.taschen + a.bank) > (b.taschen + b.bank)
  end)
  return summe, liste
end

-- Alle Materialien mit Bestand, optional nach Art und Suchtext gefiltert.
function La:Alle(art, suche)
  local gesamt = {}
  for _, c in pairs(FG.root.charaktere) do
    for _, feld in ipairs({ "taschen", "bank" }) do
      for item, n in pairs(c[feld] or {}) do gesamt[item] = (gesamt[item] or 0) + n end
    end
  end
  local liste = {}
  suche = suche and suche ~= "" and suche:lower() or nil
  for item, n in pairs(gesamt) do
    local m = FG.MATERIALIEN[item]
    local itemArt = m and m[1] or "kraut"
    local name = F:ItemName(item)
    if (not art or art == "alle" or itemArt == art) and (not suche or name:lower():find(suche, 1, true)) then
      liste[#liste + 1] = { item = item, menge = n, name = name, art = itemArt }
    end
  end
  table.sort(liste, function(a, b) return a.name < b.name end)
  return liste
end

function La:Vergessen(key)
  FG.root.charaktere[key] = nil
  FG:Rufe("lager")
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------
local function KlassenFarbe(klasse)
  local c = klasse and RAID_CLASS_COLORS and RAID_CLASS_COLORS[klasse]
  if c then return c.r, c.g, c.b end
  return 0.85, 0.85, 0.85
end

function La:TooltipItem(tt, item)
  if not (FG.db.materialTooltip and item and IstMaterial(item)) then return end
  local summe, liste = self:Bestand(item)
  if summe == 0 then return end
  tt:AddLine(" ")
  tt:AddDoubleLine("Forever Harvest", L"Gesamt: %d":format(summe), FG.farben.gold[1], FG.farben.gold[2], FG.farben.gold[3], 1, 1, 1)
  for i, e in ipairs(liste) do
    if i > 8 then tt:AddLine(L"… und %d weitere":format(#liste - 8), 0.6, 0.6, 0.6); break end
    local teile = {}
    if e.taschen > 0 then teile[#teile + 1] = L"Taschen %d":format(e.taschen) end
    if e.bank > 0 then teile[#teile + 1] = L"Bank %d":format(e.bank) end
    local r, g, b = KlassenFarbe(e.klasse)
    tt:AddDoubleLine(e.name, table.concat(teile, ", "), r, g, b, 0.9, 0.9, 0.9)
  end
  tt:Show()
end

-- Tooltip eines Vorkommens in der Welt: nötige Fertigkeit und ob es klappt.
function La:TooltipVorkommen(tt)
  if not FG.db.vorkommenTooltip then return end
  local zeile = _G[(tt.GetName and tt:GetName() or "GameTooltip") .. "TextLeft1"]
  local name = zeile and FG.Frei(zeile:GetText())
  if type(name) ~= "string" or name == "" then return end
  if tt.GetUnit and FG.Frei((tt:GetUnit())) then return end
  local typ = F:TypNachName(name)
  if not typ then return end
  local stufe = F:Stufe(typ)
  local art = F:Art(typ)
  local hat = F:Fertigkeit(art)
  if not stufe or art == "schatz" then return end
  if tt.fgZeile == name then return end
  F.letzterTooltip = { typ = typ, zeit = GetTime() }
  tt.fgZeile = name
  local ok = hat and hat >= stufe
  local c = ok and FG.farben.gruen or FG.farben.rot
  local text
  if not hat then text = L"Braucht %d, Beruf fehlt":format(stufe)
  elseif ok then text = L"Braucht %d, du hast %d (abbaubar)":format(stufe, hat)
  else text = L"Braucht %d, du hast %d (zu niedrig)":format(stufe, hat) end
  tt:AddLine(text, c[1], c[2], c[3])
  local n = F:Anzahl(typ)
  if n > 0 then tt:AddLine(L"%d bekannte Fundorte":format(n), 0.7, 0.7, 0.7) end
  tt:Show()
end

local function ItemAusTooltip(tt, daten)
  if daten and FG.Frei(daten.id) then return daten.id end
  if tt.GetItem then
    local _, link = tt:GetItem()
    link = FG.Frei(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
  end
end

function La:Start()
  self:TaschenLesen()
  FG:Ereignis("BAG_UPDATE_DELAYED", function() La:TaschenLesen() end)
  FG:Ereignis("BANKFRAME_OPENED", function() La:BankLesen(); La.bankOffen = true end)
  FG:Ereignis("BANKFRAME_CLOSED", function() La.bankOffen = false end)
  FG:Ereignis("PLAYERBANKSLOTS_CHANGED", function() if La.bankOffen then La:BankLesen() end end)
  FG:Ereignis("PLAYERREAGENTBANKSLOTS_CHANGED", function() if La.bankOffen then La:BankLesen() end end)

  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, daten)
      if tt == GameTooltip or tt == ItemRefTooltip then FG:Sicher("Tooltip", La.TooltipItem, La, tt, ItemAusTooltip(tt, daten)) end
    end)
  elseif GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetItem", function(tt) FG:Sicher("Tooltip", La.TooltipItem, La, tt, ItemAusTooltip(tt)) end)
  end
  if GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnShow", function(tt) FG:Sicher("Tooltip", La.TooltipVorkommen, La, tt) end)
    GameTooltip:HookScript("OnHide", function(tt) tt.fgZeile = nil end)
  end
end

FG:Befehl({ "lager" }, function(rest)
  local suche = rest ~= "" and rest or nil
  local liste = La:Alle(nil, suche)
  if #liste == 0 then FG:Meldung(L"Keine Sammelmaterialien gefunden."); return end
  FG:Meldung(L"%d Materialien auf allen Charakteren:", #liste)
  for i, e in ipairs(liste) do
    if i > 15 then DEFAULT_CHAT_FRAME:AddMessage("  …"); break end
    DEFAULT_CHAT_FRAME:AddMessage(("  %s: %d"):format(e.name, e.menge))
  end
end, L"/fg lager [Suche] – Materialien aller Charaktere")
