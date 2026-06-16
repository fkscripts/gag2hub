
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local lp           = Players.LocalPlayer
local Gardens      = workspace:WaitForChild("Gardens")

-- ══════════════════════════════════════════════════════════
--   EVENT REFERANSINI GÜVENLİ BUL
--   pcall ile buluruz — path yanlışsa hemen haber verir
-- ══════════════════════════════════════════════════════════
local Event
do
    local ok, result = pcall(function()
        return game:GetService("ReplicatedStorage")
            .SharedModules.Packet.RemoteEvent
    end)
    if ok and result then
        Event = result
        print("[GaG2 v4] ✅ Event bulundu: " .. result:GetFullName())
    else
        -- Alternatif path'leri dene
        local paths = {
            {"ReplicatedStorage", "Packet", "RemoteEvent"},
            {"ReplicatedStorage", "SharedModules", "RemoteEvent"},
            {"ReplicatedStorage", "RemoteEvent"},
        }
        for _, p in ipairs(paths) do
            local obj = game:GetService("ReplicatedStorage")
            local found = true
            for _, part in ipairs(p) do
                obj = obj:FindFirstChild(part)
                if not obj then found = false; break end
            end
            if found and obj:IsA("RemoteEvent") then
                Event = obj
                print("[GaG2 v4] ✅ Event alternatif path ile bulundu: " .. obj:GetFullName())
                break
            end
        end
        if not Event then
            -- Son çare: tüm ReplicatedStorage'daki ilk RemoteEvent'i bul
            local function findRemoteEvent(parent, depth)
                if depth > 4 then return nil end
                for _, v in ipairs(parent:GetChildren()) do
                    if v:IsA("RemoteEvent") then return v end
                    local found = findRemoteEvent(v, depth + 1)
                    if found then return found end
                end
            end
            Event = findRemoteEvent(game:GetService("ReplicatedStorage"), 0)
            if Event then
                print("[GaG2 v4] ⚠️ Event deep-search ile bulundu: " .. Event:GetFullName())
                print("[GaG2 v4] ⚠️ Bu yanlış event olabilir — path'i kontrol et!")
            else
                warn("[GaG2 v4] ❌ Event BULUNAMADI! Script çalışmaz.")
            end
        end
    end
end

-- Event yoksa dur
if not Event then
    warn("[GaG2 v4] FATAL: RemoteEvent bulunamadı. Script durduruldu.")
    return
end

-- ══════════════════════════════════════════════════════════
--   GERÇEK SATIŞ DEĞERLERİ (PCGamesN Ara. 2025)
-- ══════════════════════════════════════════════════════════
local FRUIT_VALUE = {
    ["Cocomango"]          = 183465,
    ["Mushroom"]           = 142443,
    ["Brussels Sprout"]    = 126443,
    ["Potato"]             = 93422,
    ["Burning Bud"]        = 79254,
    ["Briar Rose"]         = 78634,
    ["Giant Pinecone"]     = 77143,
    ["Ember Lily"]         = 71533,
    ["Broccoli"]           = 58934,
    ["Sugar Apple"]        = 55658,
    ["Beanstalk"]          = 18788,
    ["Cacao"]              = 10456,
    ["Pepper"]             = 7577,
    ["Grape"]              = 7554,
    ["Mango"]              = 6308,
    ["Dragon Fruit"]       = 4566,
    ["Bamboo"]             = 3944,
    ["Pumpkin"]            = 3854,
    ["Cactus"]             = 3224,
    ["Watermelon"]         = 2905,
    ["Coconut"]            = 2670,
    ["Daffodil"]           = 988,
    ["Orange Tulip"]       = 792,
    ["Apple"]              = 266,
    ["Corn"]               = 44,
    ["Tomato"]             = 35,
    ["Blueberry"]          = 21,
    ["Carrot"]             = 22,
    ["Strawberry"]         = 19,
    ["Sunflower"]          = 50000,
    ["Loquat"]             = 40000,
    ["Avocado"]            = 35000,
    ["Green Apple"]        = 30000,
    ["Wild Pineapple"]     = 25000,
    ["Sherrybloom"]        = 20000,
    ["Coinfruit"]          = 15000,
    ["Pinkside Dandelion"] = 10000,
}

local BUY_PRIORITY = {
    "Cocomango", "Brussels Sprout", "Mushroom", "Potato",
    "Burning Bud", "Briar Rose", "Giant Pinecone", "Ember Lily",
    "Broccoli", "Sugar Apple", "Beanstalk", "Cacao",
    "Pepper", "Grape", "Mango", "Dragon Fruit",
    "Bamboo", "Pumpkin", "Cactus", "Watermelon", "Coconut",
    "Daffodil", "Orange Tulip", "Apple",
    "Corn", "Tomato", "Blueberry", "Carrot", "Strawberry",
}
local SEED_SET = {}
for _, n in ipairs(BUY_PRIORITY) do SEED_SET[n] = true end

-- ══════════════════════════════════════════════════════════
--   GLOBAL FLAGS
-- ══════════════════════════════════════════════════════════
getgenv().AutoHarvest  = false
getgenv().AutoSell     = false
getgenv().AutoBuy      = false
getgenv().AutoPlant    = false
getgenv().SellInterval = 1.0
getgenv().BuyInterval  = 1.0
getgenv().CachedPlot   = nil

-- ══════════════════════════════════════════════════════════
--   İSTATİSTİKLER — sadece başarılı işlemde güncellenir
-- ══════════════════════════════════════════════════════════
local Stats = {
    harvestCount  = 0,
    sellCount     = 0,
    buyCount      = 0,
    plantCount    = 0,
    estimatedGold = 0,
    sessionStart  = os.clock(),
    errors        = 0,
}

-- ══════════════════════════════════════════════════════════
--   GÜVENLİ FIRE — hata yakalar, debug çıktısı verir
--   Başarılıysa true, değilse false döner
-- ══════════════════════════════════════════════════════════
local function safeFireServer(packet, extras)
    local ok, err = pcall(function()
        if extras then
            Event:FireServer(packet, extras)
        else
            Event:FireServer(packet)
        end
    end)
    if not ok then
        Stats.errors += 1
        -- İlk 10 hatayı yazdır, sonrasını bastır
        if Stats.errors <= 10 then
            warn("[GaG2 v4] FireServer hatası #" .. Stats.errors .. ": " .. tostring(err))
        end
    end
    return ok
end

-- ══════════════════════════════════════════════════════════
--   HARVEST PAKETLERİ
-- ══════════════════════════════════════════════════════════
local function buildProximityPacket(plantId, fruitId)
    return buffer.fromstring("\xB2\x00$" .. plantId .. "$" .. fruitId)
end

local function buildHarvestPacket(fruits)
    local payload   = "a\x00\x1C"
    local idx       = 1
    local shovelStr = "Shovel:Shovel"
    payload = payload
        .. "\x05" .. string.char(idx)
        .. "\x0B" .. string.char(#shovelStr) .. shovelStr
    idx += 1
    for _, f in ipairs(fruits) do
        local weight  = math.round(f.SizeMulti * 1000)
        local itemStr = "Fruit:" .. f.CorePartName .. ":" .. tostring(weight)
        payload = payload
            .. "\x05" .. string.char(idx)
            .. "\x0B" .. string.char(#itemStr) .. itemStr
        idx += 1
    end
    return buffer.fromstring(payload .. "\x00")
end

local function buildConfirmPacket(plantId, fruitId, pos)
    local b = buffer.create(12)
    buffer.writef32(b, 0, pos.X)
    buffer.writef32(b, 4, pos.Y)
    buffer.writef32(b, 8, pos.Z)
    return buffer.fromstring(
        "\x08\x01$" .. plantId .. "$" .. fruitId .. buffer.tostring(b)
    )
end

-- ══════════════════════════════════════════════════════════
--   SELL PAKETLERİ
-- ══════════════════════════════════════════════════════════
local P1 = buffer.fromstring("\x9B\x00\x1F")
local P2 = buffer.fromstring("\x9A\x00\x20")
local P3 = buffer.fromstring("a\x00\x1C\x05\x01\x0B\x0DShovel:Shovel\x00")

-- ══════════════════════════════════════════════════════════
--   BUY PAKETİ CACHE
-- ══════════════════════════════════════════════════════════
local buyPacketCache = {}
local function buyPacket(seedName)
    if not buyPacketCache[seedName] then
        buyPacketCache[seedName] =
            buffer.fromstring("h\x00" .. string.char(#seedName) .. seedName)
    end
    return buyPacketCache[seedName]
end

-- ══════════════════════════════════════════════════════════
--   PLANT VERİSİ — olgun meyveler, değere göre sıralı
-- ══════════════════════════════════════════════════════════
local function getPlantData()
    local plantMap = {}
    for _, plot in ipairs(Gardens:GetChildren()) do
        local plantsFolder = plot:FindFirstChild("Plants")
        if not plantsFolder then continue end
        for _, plant in ipairs(plantsFolder:GetChildren()) do
            local fruitsFolder = plant:FindFirstChild("Fruits")
            if not fruitsFolder then continue end
            for _, fruit in ipairs(fruitsFolder:GetChildren()) do
                local coreName  = fruit:GetAttribute("CorePartName")
                local sizeMulti = fruit:GetAttribute("SizeMulti")
                local plantId   = fruit:GetAttribute("PlantId")
                local fruitId   = fruit:GetAttribute("FruitId")
                local age       = fruit:GetAttribute("Age")
                local maxAge    = fruit:GetAttribute("MaxAge")
                if not (coreName and sizeMulti and plantId and fruitId) then continue end
                if age and maxAge and age < maxAge then continue end
                if not plantMap[plantId] then
                    local pos = Vector3.new(0, 0, 0)
                    if fruit:IsA("Model") then
                        local part = fruit:FindFirstChildWhichIsA("BasePart")
                        if part then pos = part.Position end
                    elseif fruit:IsA("BasePart") then
                        pos = fruit.Position
                    end
                    plantMap[plantId] = {
                        plantId    = plantId,
                        firstFruit = { id = fruitId, pos = pos },
                        fruits     = {},
                        totalValue = 0,
                    }
                end
                local v = FRUIT_VALUE[coreName] or 0
                plantMap[plantId].totalValue += v
                table.insert(plantMap[plantId].fruits, {
                    CorePartName = coreName,
                    SizeMulti    = sizeMulti,
                    Value        = v,
                })
            end
        end
    end
    local sorted = {}
    for _, data in pairs(plantMap) do
        table.sort(data.fruits, function(a, b) return a.Value > b.Value end)
        table.insert(sorted, data)
    end
    table.sort(sorted, function(a, b) return a.totalValue > b.totalValue end)
    return sorted
end

-- ══════════════════════════════════════════════════════════
--   PLANT HELPERs
-- ══════════════════════════════════════════════════════════
local SPACING = 5

local function getOwnPlot()
    if getgenv().CachedPlot and getgenv().CachedPlot.Parent then
        return getgenv().CachedPlot
    end
    local uid = tostring(lp.UserId)
    for _, plot in ipairs(Gardens:GetChildren()) do
        local pf = plot:FindFirstChild("Plants")
        if pf then
            for _, plant in ipairs(pf:GetChildren()) do
                if plant.Name:sub(1, #uid) == uid then
                    getgenv().CachedPlot = plot; return plot
                end
            end
        end
    end
    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        local myPos = lp.Character.HumanoidRootPart.Position
        local best, bestDist = nil, math.huge
        for _, plot in ipairs(Gardens:GetChildren()) do
            local sp = plot:FindFirstChild("SpawnPoint")
            if sp then
                local d = (sp.Position - myPos).Magnitude
                if d < bestDist then bestDist = d; best = plot end
            end
        end
        if best and bestDist < 150 then
            getgenv().CachedPlot = best; return best
        end
    end
end

local function columnToPositions(col)
    local positions = {}
    local cx, cy, cz = col.Position.X, col.Position.Y, col.Position.Z
    local sx, sz = col.Size.X, col.Size.Z
    local Y = cy + 0.25
    local x = cx - sx/2 + SPACING/2
    while x <= cx + sx/2 - SPACING/2 + 0.01 do
        local z = cz - sz/2 + SPACING/2
        while z <= cz + sz/2 - SPACING/2 + 0.01 do
            table.insert(positions, Vector3.new(x, Y, z))
            z = z + SPACING
        end
        x = x + SPACING
    end
    return positions
end

local function isOccupied(pos, plantsFolder, pending)
    for _, plant in ipairs(plantsFolder:GetChildren()) do
        local base = plant:FindFirstChildWhichIsA("BasePart", true)
        if base then
            local dx = base.Position.X - pos.X
            local dz = base.Position.Z - pos.Z
            if dx*dx + dz*dz < 9 then return true end
        end
    end
    for _, p in ipairs(pending) do
        local dx = p.X - pos.X; local dz = p.Z - pos.Z
        if dx*dx + dz*dz < 9 then return true end
    end
    return false
end

local function buildPlantPacket(seedName, pos)
    local b = buffer.create(12)
    buffer.writef32(b, 0, pos.X)
    buffer.writef32(b, 4, pos.Y)
    buffer.writef32(b, 8, pos.Z)
    return buffer.fromstring(
        "\x04\x00" .. buffer.tostring(b) .. string.char(#seedName) .. seedName
    )
end

local function nextSeed()
    local bestTool, bestVal = nil, -1
    for _, tool in ipairs(lp.Backpack:GetChildren()) do
        if SEED_SET[tool.Name] then
            local v = FRUIT_VALUE[tool.Name] or 0
            if v > bestVal then bestVal = v; bestTool = tool end
        end
    end
    if lp.Character then
        for _, tool in ipairs(lp.Character:GetChildren()) do
            if tool:IsA("Tool") and SEED_SET[tool.Name] then
                local v = FRUIT_VALUE[tool.Name] or 0
                if v > bestVal then bestVal = v; bestTool = tool end
            end
        end
    end
    return bestTool
end

local function plantAt(pos)
    local tool = nextSeed()
    if not tool then return false end
    local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return false end
    hrp.CFrame = CFrame.new(pos.X, pos.Y + 3, pos.Z)
    task.wait(0.08)
    if tool.Parent == lp.Backpack then
        hum:EquipTool(tool); task.wait(0.08)
    end
    local equipped = lp.Character:FindFirstChild(tool.Name)
    if not equipped then hum:UnequipTools(); return false end
    local ok = safeFireServer(buildPlantPacket(equipped.Name, pos), {equipped})
    task.wait(0.08)
    hum:UnequipTools()
    return ok
end

task.defer(function() getOwnPlot() end)

-- ══════════════════════════════════════════════════════════
--   TIER SİSTEMİ
-- ══════════════════════════════════════════════════════════
local PROFIT_TIERS = {
    { label = "💎 GOD",    minGph = 5000000 },
    { label = "🔥 S-TIER", minGph = 1000000 },
    { label = "⚡ A-TIER", minGph = 500000  },
    { label = "✅ B-TIER", minGph = 100000  },
    { label = "📈 C-TIER", minGph = 10000   },
    { label = "🌱 D-TIER", minGph = 0       },
}
local function getProfitTier(gph)
    for _, t in ipairs(PROFIT_TIERS) do
        if gph >= t.minGph then return t.label end
    end
    return "🌱 D-TIER"
end

-- ══════════════════════════════════════════════════════════
--   GUI
-- ══════════════════════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "GaG2FarmGui_v4"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = game:GetService("CoreGui")

local Frame = Instance.new("Frame", ScreenGui)
Frame.Size             = UDim2.new(0, 270, 0, 490)
Frame.Position         = UDim2.new(0, 20, 0, 20)
Frame.BackgroundColor3 = Color3.fromRGB(10, 11, 16)
Frame.BorderSizePixel  = 0
Frame.Active           = true
Frame.Draggable        = true
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 14)
local glow = Instance.new("UIStroke", Frame)
glow.Color = Color3.fromRGB(60, 200, 80); glow.Thickness = 1.5; glow.Transparency = 0.4

local TitleBar = Instance.new("Frame", Frame)
TitleBar.Size = UDim2.new(1, 0, 0, 44)
TitleBar.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
TitleBar.BorderSizePixel = 0
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 14)

local TitleLbl = Instance.new("TextLabel", TitleBar)
TitleLbl.Size = UDim2.new(1, -12, 1, 0); TitleLbl.Position = UDim2.new(0, 12, 0, 0)
TitleLbl.BackgroundTransparency = 1; TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextColor3 = Color3.fromRGB(60, 220, 80); TitleLbl.TextSize = 14
TitleLbl.Text = "🌱 GaG2 MAX PROFIT v4.0"; TitleLbl.TextXAlignment = Enum.TextXAlignment.Left

local Div = Instance.new("Frame", Frame)
Div.Size = UDim2.new(1, -24, 0, 1); Div.Position = UDim2.new(0, 12, 0, 48)
Div.BackgroundColor3 = Color3.fromRGB(35, 38, 50); Div.BorderSizePixel = 0

local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad)

local function makeRow(yPos, label, sub)
    local row = Instance.new("Frame", Frame)
    row.Size = UDim2.new(1, -20, 0, 58); row.Position = UDim2.new(0, 10, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(18, 20, 28); row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1, -10, 0, 32); btn.Position = UDim2.new(0, 5, 0, 5)
    btn.BackgroundColor3 = Color3.fromRGB(160, 35, 35); btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.TextSize = 13
    btn.Text = label .. ": OFF"; btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local status = Instance.new("TextLabel", row)
    status.Size = UDim2.new(1, 0, 0, 16); status.Position = UDim2.new(0, 6, 0, 40)
    status.BackgroundTransparency = 1; status.Font = Enum.Font.Gotham
    status.TextColor3 = Color3.fromRGB(90, 90, 110); status.TextSize = 10
    status.Text = sub or "Idle"; status.TextXAlignment = Enum.TextXAlignment.Left
    return btn, status
end

local harvestBtn, harvestStatus = makeRow(55,  "Auto Harvest", "Bekliyor")
local sellBtn,    sellStatus    = makeRow(125, "Auto Sell",    "Bekliyor")
local buyBtn,     buyStatus     = makeRow(195, "Auto Buy",     "Bekliyor")
local plantBtn,   plantStatus   = makeRow(265, "Auto Plant",   "Bekliyor")

-- Debug / hata satırı
local debugBox = Instance.new("Frame", Frame)
debugBox.Size = UDim2.new(1, -20, 0, 22); debugBox.Position = UDim2.new(0, 10, 0, 333)
debugBox.BackgroundColor3 = Color3.fromRGB(30, 10, 10); debugBox.BorderSizePixel = 0
Instance.new("UICorner", debugBox).CornerRadius = UDim.new(0, 6)
local debugLbl = Instance.new("TextLabel", debugBox)
debugLbl.Size = UDim2.new(1, -8, 1, 0); debugLbl.Position = UDim2.new(0, 4, 0, 0)
debugLbl.BackgroundTransparency = 1; debugLbl.Font = Enum.Font.Gotham
debugLbl.TextColor3 = Color3.fromRGB(255, 100, 100); debugLbl.TextSize = 10
debugLbl.Text = "🔍 Debug: Başlatılıyor..."; debugLbl.TextXAlignment = Enum.TextXAlignment.Left

-- Performans paneli
local profitBox = Instance.new("Frame", Frame)
profitBox.Size = UDim2.new(1, -20, 0, 108); profitBox.Position = UDim2.new(0, 10, 0, 365)
profitBox.BackgroundColor3 = Color3.fromRGB(12, 22, 14); profitBox.BorderSizePixel = 0
Instance.new("UICorner", profitBox).CornerRadius = UDim.new(0, 10)
local profitStroke = Instance.new("UIStroke", profitBox)
profitStroke.Color = Color3.fromRGB(40, 160, 60); profitStroke.Thickness = 1; profitStroke.Transparency = 0.5

local function makePL(yp, bold)
    local l = Instance.new("TextLabel", profitBox)
    l.Size = UDim2.new(1, -10, 0, 18); l.Position = UDim2.new(0, 8, 0, yp)
    l.BackgroundTransparency = 1
    l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextColor3 = bold and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(180, 180, 180)
    l.TextSize = bold and 12 or 11; l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end
local pl0 = makePL(4,  false); pl0.Text = "📊 CANLI PERFORMANS"; pl0.TextColor3 = Color3.fromRGB(60, 200, 80); pl0.Font = Enum.Font.GothamBold
local pl1 = makePL(24, false)
local pl2 = makePL(44, true)
local pl3 = makePL(64, false)
local pl4 = makePL(84, false); pl4.TextColor3 = Color3.fromRGB(255, 100, 100)

local function toggle(btn, flag, label, onSub, statusLbl)
    getgenv()[flag] = not getgenv()[flag]
    if getgenv()[flag] then
        btn.Text = label .. ": ON"; statusLbl.Text = onSub
        statusLbl.TextColor3 = Color3.fromRGB(60, 210, 90)
        TweenService:Create(btn, tweenInfo, { BackgroundColor3 = Color3.fromRGB(35, 155, 45) }):Play()
    else
        btn.Text = label .. ": OFF"; statusLbl.Text = "Idle"
        statusLbl.TextColor3 = Color3.fromRGB(90, 90, 110)
        TweenService:Create(btn, tweenInfo, { BackgroundColor3 = Color3.fromRGB(160, 35, 35) }):Play()
    end
end

harvestBtn.MouseButton1Click:Connect(function() toggle(harvestBtn, "AutoHarvest", "Auto Harvest", "Taranıyor...",   harvestStatus) end)
sellBtn.MouseButton1Click:Connect(function()    toggle(sellBtn,    "AutoSell",    "Auto Sell",    "Satılıyor...",    sellStatus)    end)
buyBtn.MouseButton1Click:Connect(function()     toggle(buyBtn,     "AutoBuy",     "Auto Buy",     "Alınıyor...",     buyStatus)     end)
plantBtn.MouseButton1Click:Connect(function()   toggle(plantBtn,   "AutoPlant",   "Auto Plant",   "Ekiliyor...",     plantStatus)   end)

-- ══════════════════════════════════════════════════════════
--   CANLI PERFORMANS — her 5sn, sadece gerçek Stats'tan
-- ══════════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(5)
        local elapsed = os.clock() - Stats.sessionStart
        local hrs     = elapsed / 3600
        local gph     = hrs > 0.0001 and math.floor(Stats.estimatedGold / hrs) or 0
        local mins    = math.floor(elapsed / 60)
        local secs    = math.floor(elapsed % 60)

        local function fmt(n)
            if n >= 1000000 then return string.format("%.2fM", n/1000000)
            elseif n >= 1000 then return string.format("%.1fK", n/1000)
            else return tostring(math.floor(n)) end
        end

        pl1.Text = string.format("⏱ %dm%ds | 🌾 %d hasat | 💸 %d sat",
            mins, secs, Stats.harvestCount, Stats.sellCount)
        pl2.Text = string.format("💰 ~%s /saat | Toplam: %s", fmt(gph), fmt(Stats.estimatedGold))
        pl3.Text = "🏆 Tier: " .. getProfitTier(gph)
        pl4.Text = string.format("❌ Hata: %d | 🌱 Ekilen: %d | 🛒 Alınan: %d",
            Stats.errors, Stats.plantCount, Stats.buyCount)

        debugLbl.Text = Stats.errors > 0
            and ("⚠️ " .. Stats.errors .. " hata var — Output'u kontrol et")
            or  ("✅ Event OK | " .. Event:GetFullName())
    end
end)

-- ══════════════════════════════════════════════════════════
--   AUTO HARVEST LOOP
--   FIX: Stats sadece safeFireServer başarılıysa artar
-- ══════════════════════════════════════════════════════════
task.spawn(function()
    while true do
        if getgenv().AutoHarvest then
            local sortedPlants = getPlantData()
            if #sortedPlants == 0 then
                harvestStatus.Text = "Olgun meyve yok..."
                task.wait(1.5)
            else
                harvestStatus.Text = string.format("🔍 %d olgun bitki", #sortedPlants)
                for _, data in ipairs(sortedPlants) do
                    if not getgenv().AutoHarvest then break end
                    local pId = data.plantId
                    local fId = data.firstFruit.id
                    local pos = data.firstFruit.pos

                    local ok1 = safeFireServer(buildProximityPacket(pId, fId))
                    task.wait(0.05)
                    local ok2 = safeFireServer(buildHarvestPacket(data.fruits))
                    task.wait(0.05)
                    local ok3 = safeFireServer(buildConfirmPacket(pId, fId, pos))

                    -- SADECE üç paket de başarılıysa stats artar
                    if ok1 and ok2 and ok3 then
                        Stats.harvestCount  += #data.fruits
                        Stats.estimatedGold += data.totalValue
                        harvestStatus.Text = string.format(
                            "✅ %d hasat | +%d", Stats.harvestCount, data.totalValue)
                    else
                        harvestStatus.Text = string.format(
                            "⚠️ Paket hatası (%s%s%s)",
                            ok1 and "✓" or "✗",
                            ok2 and "✓" or "✗",
                            ok3 and "✓" or "✗")
                    end
                    task.wait(0.06)
                end
            end
            task.wait(0.08)
        else
            task.wait(0.3)
        end
    end
end)

-- ══════════════════════════════════════════════════════════
--   AUTO SELL LOOP
-- ══════════════════════════════════════════════════════════
task.spawn(function()
    while true do
        if getgenv().AutoSell then
            local ok1 = safeFireServer(P1)
            task.wait(0.05)
            local ok2 = safeFireServer(P2)
            task.wait(0.05)
            local ok3 = safeFireServer(P3)

            if ok1 and ok2 and ok3 then
                Stats.sellCount += 1
                sellStatus.Text = string.format("✅ Satış: %dx", Stats.sellCount)
            else
                sellStatus.Text = "⚠️ Satış paketi hatası"
            end
            task.wait(getgenv().SellInterval)
        else
            task.wait(0.3)
        end
    end
end)

-- ══════════════════════════════════════════════════════════
--   AUTO BUY LOOP
-- ══════════════════════════════════════════════════════════
task.spawn(function()
    while true do
        if getgenv().AutoBuy then
            for _, name in ipairs(BUY_PRIORITY) do
                if not getgenv().AutoBuy then break end
                local ok = safeFireServer(buyPacket(name))
                if ok then
                    Stats.buyCount += 1
                    buyStatus.Text = string.format("✅ %d alım | %s", Stats.buyCount, name)
                else
                    buyStatus.Text = "⚠️ Buy paketi hatası: " .. name
                end
                task.wait(0.07)
            end
            task.wait(getgenv().BuyInterval)
        else
            task.wait(0.3)
        end
    end
end)

-- ══════════════════════════════════════════════════════════
--   AUTO PLANT LOOP
-- ══════════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(0.1)
        if not getgenv().AutoPlant then continue end
        local plot = getOwnPlot()
        if not plot then
            plantStatus.Text = "❌ Plot bulunamadı"
            task.wait(3); continue
        end
        local vis    = plot:FindFirstChild("Visual")
        local plants = plot:FindFirstChild("Plants")
        if not vis or not plants then task.wait(2); continue end
        local col1 = vis:FindFirstChild("PlantAreaColumn1")
        local col2 = vis:FindFirstChild("PlantAreaColumn2")
        local allPos = {}
        if col1 then for _, p in ipairs(columnToPositions(col1)) do table.insert(allPos, p) end end
        if col2 then for _, p in ipairs(columnToPositions(col2)) do table.insert(allPos, p) end end
        if #allPos == 0 then task.wait(2); continue end
        local pending = {}
        local planted = 0
        for _, tilePos in ipairs(allPos) do
            if not getgenv().AutoPlant then break end
            if isOccupied(tilePos, plants, pending) then continue end
            local tool = nextSeed()
            if not tool then
                plantStatus.Text = "❌ Seed yok — Auto Buy açık mı?"
                break
            end
            local ok = plantAt(tilePos)
            if ok then
                planted += 1; Stats.plantCount += 1
                table.insert(pending, tilePos)
                plantStatus.Text = string.format("🌱 %d ekildi | %s", planted, tool.Name)
            else
                plantStatus.Text = "⚠️ Plant paketi hatası"
            end
            task.wait(0.3)
        end
        local sp = plot:FindFirstChild("SpawnPoint")
        if sp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
            lp.Character.HumanoidRootPart.CFrame =
                CFrame.new(sp.Position + Vector3.new(0, 3, 0))
        end
        task.wait(3)
    end
end)
