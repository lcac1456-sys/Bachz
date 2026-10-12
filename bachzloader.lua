-- ============================================
--   [BACHZ] MENU LOADER BY BACHZ
--   cre bachz
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera

local BIN_ID = "6acc6e51ac6210605a298d84"
local MASTER_KEY = "$2a$10$aO4fgemBav88hoR.CwwQaecU1kyaihgjqfaLggUsqta/oFzXTwxGq"
local CHECK_INTERVAL = 15
local KEY_URL = "https://api.jsonbin.io/v3/b/" .. BIN_ID .. "/latest"
local UPDATE_URL = "https://api.jsonbin.io/v3/b/" .. BIN_ID
local FILE_NAME = "bachz_key.txt"
local CONFIG_FILE = "bachz_config.json"

local function writeKeyFile(k)
    if type(writefile) == "function" then pcall(writefile, FILE_NAME, k); return true end
    if type(WriteFile) == "function" then pcall(WriteFile, FILE_NAME, k); return true end
    return false
end

local function readKeyFile()
    if type(isfile) == "function" and type(readfile) == "function" then
        local ok, ex = pcall(isfile, FILE_NAME)
        if ok and ex then
            local rok, c = pcall(readfile, FILE_NAME)
            if rok and c and c ~= "" then return c end
        end
    end
    if type(ReadFile) == "function" then
        local ok, c = pcall(ReadFile, FILE_NAME)
        if ok and c and c ~= "" then return c end
    end
    return nil
end

local function deleteKeyFile()
    if type(delfile) == "function" then pcall(delfile, FILE_NAME); return true end
    if type(DelFile) == "function" then pcall(DelFile, FILE_NAME); return true end
    return false
end

local function httpGet(url, headers)
    if type(request) == "function" then
        local ok, res = pcall(request, { Url = url, Method = "GET", Headers = headers })
        if ok and res and res.Body then return res.Body end
    end
    if type(http_request) == "function" then
        local ok, res = pcall(http_request, { Url = url, Method = "GET", Headers = headers })
        if ok and res and res.Body then return res.Body end
    end
    if syn and type(syn.request) == "function" then
        local ok, res = pcall(syn.request, { Url = url, Method = "GET", Headers = headers })
        if ok and res and res.Body then return res.Body end
    end
    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    if ok and res then return res end
    return nil
end

local function httpPut(url, headers, body)
    if type(request) == "function" then
        local ok, res = pcall(request, { Url = url, Method = "PUT", Headers = headers, Body = body })
        if ok and res then return res.Body end
    end
    if type(http_request) == "function" then
        local ok, res = pcall(http_request, { Url = url, Method = "PUT", Headers = headers, Body = body })
        if ok and res then return res.Body end
    end
    if syn and type(syn.request) == "function" then
        local ok, res = pcall(syn.request, { Url = url, Method = "PUT", Headers = headers, Body = body })
        if ok and res then return res.Body end
    end
    return nil
end

local function getHWID()
    if type(gethwid) == "function" then
        local ok, id = pcall(gethwid)
        if ok and id then return id end
    end
    if type(game.GetService) == "function" then
        local ok, id = pcall(function()
            return game:GetService("RbxAnalyticsService"):GetClientId()
        end)
        if ok and id then return id end
    end
    return tostring(LP.UserId) .. "-" .. LP.Name
end

local function getDeviceName()
    if type(getname) == "function" then
        local ok, n = pcall(getname)
        if ok and n then return n end
    end
    return "Unknown"
end

local HWID = getHWID()
local DEVICE = getDeviceName()

local function fetchData()
    local raw = httpGet(KEY_URL, {
        ["X-Master-Key"] = MASTER_KEY,
        ["X-Bin-Meta"] = "false",
    })
    if not raw or raw == "" then return nil end
    local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok or type(decoded) ~= "table" then return nil end
    if decoded.record then return decoded.record end
    return decoded
end

local function parseIso(iso)
    local y, mo, d, h, mi, s = iso:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if not y then return nil end
    return os.time({
        year = tonumber(y), month = tonumber(mo), day = tonumber(d),
        hour = tonumber(h), min = tonumber(mi), sec = tonumber(s),
        isdst = false,
    })
end

local function validateKey(inputKey)
    if type(inputKey) ~= "string" or inputKey == "" then
        return { valid = false, reason = "empty" }
    end
    local data = fetchData()
    if not data then return { valid = false, reason = "no_connection" } end
    if type(data.keys) ~= "table" then return { valid = false, reason = "no_data" } end

    if type(data.banned) == "table" then
        for _, b in ipairs(data.banned) do
            if b == inputKey then
                return { valid = false, reason = "banned" }
            end
        end
    end

    local info = data.keys[inputKey]
    if not info then return { valid = false, reason = "not_found" } end
    if info.kick then return { valid = false, reason = "kicked" } end

    if info.expire and info.expire ~= "forever" then
        local exp = parseIso(info.expire)
        if exp and os.time() > exp then
            return { valid = false, reason = "expired" }
        end
    end

    return { valid = true, info = info }
end

local function reportDevice(inputKey)
    local data = fetchData()
    if not data or not data.keys or not data.keys[inputKey] then return end
    local info = data.keys[inputKey]
    info.hwid = HWID
    info.device = DEVICE
    info.last_seen = os.date("!%Y-%m-%dT%H:%M:%S")
    local body = HttpService:JSONEncode(data)
    httpPut(UPDATE_URL, {
        ["Content-Type"] = "application/json",
        ["X-Master-Key"] = MASTER_KEY,
    }, body)
end
local function showKeyGui(prefill)
    local Gui = Instance.new("ScreenGui")
    Gui.Name = "BachzKeyGui"
    Gui.IgnoreGuiInset = true
    Gui.ResetOnSpawn = false
    local ok2 = pcall(function() Gui.Parent = CoreGui end)
    if not ok2 then Gui.Parent = LP:WaitForChild("PlayerGui") end

    local Frame = Instance.new("Frame", Gui)
    Frame.Size = UDim2.new(0, 340, 0, 250)
    Frame.Position = UDim2.new(0.5, -170, 0.5, -125)
    Frame.BackgroundColor3 = Color3.fromRGB(6, 10, 14)
    Frame.BorderSizePixel = 0
    Frame.Active = true
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke", Frame)
    stroke.Color = Color3.fromRGB(0, 255, 140)
    stroke.Thickness = 2

    local Title = Instance.new("TextLabel", Frame)
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundTransparency = 1
    Title.Text = "MENU LOADER BY BACHZ"
    Title.TextColor3 = Color3.fromRGB(0, 255, 140)
    Title.Font = Enum.Font.GothamBlack
    Title.TextSize = 16

    local Sub = Instance.new("TextLabel", Frame)
    Sub.Size = UDim2.new(1, 0, 0, 20)
    Sub.Position = UDim2.new(0, 0, 0, 45)
    Sub.BackgroundTransparency = 1
    Sub.Text = "Nhập key để sử dụng"
    Sub.TextColor3 = Color3.fromRGB(180, 180, 180)
    Sub.Font = Enum.Font.Gotham
    Sub.TextSize = 12

    local Box = Instance.new("TextBox", Frame)
    Box.Size = UDim2.new(1, -40, 0, 38)
    Box.Position = UDim2.new(0, 20, 0, 78)
    Box.BackgroundColor3 = Color3.fromRGB(12, 18, 24)
    Box.BorderSizePixel = 0
    Box.Text = prefill or ""
    Box.PlaceholderText = "LD-XXXX-XXXX-XXXX-XXXX"
    Box.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
    Box.TextColor3 = Color3.fromRGB(240, 240, 240)
    Box.Font = Enum.Font.GothamBold
    Box.TextSize = 13
    Box.ClearTextOnFocus = false
    Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 8)
    local bStroke = Instance.new("UIStroke", Box)
    bStroke.Color = Color3.fromRGB(42, 42, 58)
    bStroke.Thickness = 1

    local remember = (prefill ~= nil and prefill ~= "")
    local RemBtn = Instance.new("TextButton", Frame)
    RemBtn.Size = UDim2.new(1, -40, 0, 24)
    RemBtn.Position = UDim2.new(0, 20, 0, 122)
    RemBtn.BackgroundTransparency = 1
    RemBtn.Text = ""
    RemBtn.AutoButtonColor = false

    local RBox = Instance.new("Frame", RemBtn)
    RBox.Size = UDim2.new(0, 16, 0, 16)
    RBox.Position = UDim2.new(0, 0, 0.5, -8)
    RBox.BackgroundColor3 = remember and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(35, 45, 55)
    RBox.BorderSizePixel = 0
    Instance.new("UICorner", RBox).CornerRadius = UDim.new(0, 4)

    local RCheck = Instance.new("TextLabel", RBox)
    RCheck.Size = UDim2.new(1, 0, 1, 0)
    RCheck.BackgroundTransparency = 1
    RCheck.Text = "✓"
    RCheck.TextColor3 = Color3.fromRGB(255, 255, 255)
    RCheck.Font = Enum.Font.GothamBlack
    RCheck.TextSize = 12
    RCheck.Visible = remember

    local RLabel = Instance.new("TextLabel", RemBtn)
    RLabel.Size = UDim2.new(1, -24, 1, 0)
    RLabel.Position = UDim2.new(0, 22, 0, 0)
    RLabel.BackgroundTransparency = 1
    RLabel.Text = "Ghi nhớ key (auto login)"
    RLabel.TextColor3 = Color3.fromRGB(180, 200, 190)
    RLabel.Font = Enum.Font.Gotham
    RLabel.TextSize = 11
    RLabel.TextXAlignment = Enum.TextXAlignment.Left

    RemBtn.MouseButton1Click:Connect(function()
        remember = not remember
        RBox.BackgroundColor3 = remember and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(35, 45, 55)
        RCheck.Visible = remember
    end)

    local Btn = Instance.new("TextButton", Frame)
    Btn.Size = UDim2.new(1, -40, 0, 40)
    Btn.Position = UDim2.new(0, 20, 0, 158)
    Btn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    Btn.BorderSizePixel = 0
    Btn.Text = "XÁC NHẬN"
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Font = Enum.Font.GothamBlack
    Btn.TextSize = 14
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)

    local ForgetBtn = Instance.new("TextButton", Frame)
    ForgetBtn.Size = UDim2.new(1, -40, 0, 26)
    ForgetBtn.Position = UDim2.new(0, 20, 0, 206)
    ForgetBtn.BackgroundTransparency = 1
    ForgetBtn.Text = "Quên key đã lưu"
    ForgetBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
    ForgetBtn.Font = Enum.Font.Gotham
    ForgetBtn.TextSize = 11
    ForgetBtn.AutoButtonColor = false
    ForgetBtn.MouseButton1Click:Connect(function()
        deleteKeyFile()
        Box.Text = ""
        Box.PlaceholderText = "Đã xoá key đã lưu"
        Box.PlaceholderColor3 = Color3.fromRGB(255, 200, 80)
        remember = false
        RBox.BackgroundColor3 = Color3.fromRGB(35, 45, 55)
        RCheck.Visible = false
    end)

    local result = { done = false, key = nil }
    local busy = false

    Btn.MouseButton1Click:Connect(function()
        if busy then return end
        local inputKey = Box.Text
        if inputKey == "" then
            Box.PlaceholderText = "Nhập key!"
            Box.PlaceholderColor3 = Color3.fromRGB(255, 150, 50)
            return
        end
        busy = true
        Btn.Text = "ĐANG CHECK..."
        Btn.BackgroundColor3 = Color3.fromRGB(120, 120, 120)

        task.spawn(function()
            local res = validateKey(inputKey)
            if res.valid then
                if remember then
                    writeKeyFile(inputKey)
                else
                    deleteKeyFile()
                end
                task.spawn(function() pcall(reportDevice, inputKey) end)
                result.done = true
                result.key = inputKey
                Gui:Destroy()
            else
                local msg = "Key sai! Thử lại..."
                local col = Color3.fromRGB(255, 50, 50)
                if res.reason == "banned" then
                    msg, col = "KEY ĐÃ BỊ BAN!", Color3.fromRGB(255, 50, 50)
                elseif res.reason == "expired" then
                    msg, col = "KEY HẾT HẠN!", Color3.fromRGB(255, 150, 50)
                elseif res.reason == "kicked" then
                    msg, col = "BẠN ĐÃ BỊ KICK!", Color3.fromRGB(255, 50, 50)
                elseif res.reason == "not_found" then
                    msg, col = "KEY KHÔNG TỒN TẠI!", Color3.fromRGB(255, 50, 50)
                elseif res.reason == "no_connection" then
                    msg, col = "Không kết nối được!", Color3.fromRGB(255, 50, 50)
                elseif res.reason == "no_data" then
                    msg, col = "Server lỗi data!", Color3.fromRGB(255, 50, 50)
                end
                Box.Text = ""
                Box.PlaceholderText = msg
                Box.PlaceholderColor3 = col
                Btn.Text = "XÁC NHẬN"
                Btn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
                busy = false
            end
        end)
    end)

    while not result.done do
        if not Gui.Parent then return nil end
        task.wait(0.1)
    end
    return result.key
end

local function tryAutoLogin()
    local saved = readKeyFile()
    if not saved or saved == "" then return nil, nil end
    local res = validateKey(saved)
    if res.valid then
        task.spawn(function() pcall(reportDevice, saved) end)
        return saved, saved
    end
    deleteKeyFile()
    return nil, nil
end

local autoKey, prefillKey = tryAutoLogin()
local key
if autoKey then
    key = autoKey
    print("[BACHZ] Auto-login OK")
else
    key = showKeyGui(prefillKey)
end
if not key then return end

local KEY_START = tick()
local KEY_INFO = "?"
do
    local data = fetchData()
    if data and data.keys and data.keys[key] then
        local info = data.keys[key]
        if info.expire == "forever" then
            KEY_INFO = "Vĩnh viễn"
        elseif info.expire then
            local exp = parseIso(info.expire)
            if exp then
                local remain = exp - os.time()
                if remain > 0 then
                    local d = math.floor(remain / 86400)
                    local h = math.floor((remain % 86400) / 3600)
                    local m = math.floor((remain % 3600) / 60)
                    if d > 0 then
                        KEY_INFO = d .. "d " .. h .. "h"
                    elseif h > 0 then
                        KEY_INFO = h .. "h " .. m .. "m"
                    else
                        KEY_INFO = m .. "m"
                    end
                else
                    KEY_INFO = "Hết hạn"
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(CHECK_INTERVAL)
        local ok, res = pcall(validateKey, key)
        if not ok or not res or not res.valid then
            local reason = "Key không hợp lệ!"
            if res and res.reason == "banned" then reason = "Key đã bị BAN!"
            elseif res and res.reason == "expired" then reason = "Key đã HẾT HẠN!"
            elseif res and res.reason == "kicked" then reason = "Bạn đã bị KICK!"
            elseif res and res.reason == "not_found" then reason = "Key đã bị XÓA!"
            elseif res and res.reason == "no_connection" then continue end
            LP:Kick("BACHZ LOADER: " .. reason)
            break
        end
    end
end)

local CFG = {
    aim_enabled = false,
    aim_fov = 300,
    aim_smooth = 0.08,
    aim_pred = 0.15,
    aim_wall = false,
    aim_head_off = 0,
    aim_show_fov = false,
    aim_show_dot = false,
    silent_enabled = false,
    silent_key = Enum.UserInputType.MouseButton2,
    silent_show = false,
    spin_enabled = false,
    spin_speed = 20,
    esp_enabled = true,
    esp_line = true,
    esp_box = true,
    esp_count = true,
    esp_name = true,
    esp_dist = true,
    esp_max = 800,
    esp_box_color = Color3.fromRGB(0, 255, 140),
    esp_line_color = Color3.fromRGB(255, 60, 60),
    info_enabled = false,
    info_show_players = true,
    info_show_fps = true,
    info_show_ping = true,
    info_show_time = true,
    info_show_velocity = false,
}

local function saveConfig()
    local data = {
        aim_enabled = CFG.aim_enabled,
        aim_fov = CFG.aim_fov,
        aim_smooth = CFG.aim_smooth,
        aim_pred = CFG.aim_pred,
        aim_wall = CFG.aim_wall,
        aim_head_off = CFG.aim_head_off,
        aim_show_fov = CFG.aim_show_fov,
        aim_show_dot = CFG.aim_show_dot,
        silent_enabled = CFG.silent_enabled,
        silent_show = CFG.silent_show,
        spin_enabled = CFG.spin_enabled,
        spin_speed = CFG.spin_speed,
        esp_enabled = CFG.esp_enabled,
        esp_line = CFG.esp_line,
        esp_box = CFG.esp_box,
        esp_name = CFG.esp_name,
        esp_dist = CFG.esp_dist,
        esp_count = CFG.esp_count,
        esp_max = CFG.esp_max,
        info_enabled = CFG.info_enabled,
        info_show_players = CFG.info_show_players,
        info_show_fps = CFG.info_show_fps,
        info_show_ping = CFG.info_show_ping,
        info_show_time = CFG.info_show_time,
        info_show_velocity = CFG.info_show_velocity,
    }
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if ok and encoded then
        if type(writefile) == "function" then pcall(writefile, CONFIG_FILE, encoded) end
        if type(WriteFile) == "function" then pcall(WriteFile, CONFIG_FILE, encoded) end
    end
end

local function loadConfig()
    local content
    if type(isfile) == "function" and type(readfile) == "function" then
        local ok, ex = pcall(isfile, CONFIG_FILE)
        if ok and ex then
            local rok, c = pcall(readfile, CONFIG_FILE)
            if rok then content = c end
        end
    end
    if not content and type(ReadFile) == "function" then
        local ok, c = pcall(ReadFile, CONFIG_FILE)
        if ok then content = c end
    end
    if not content or content == "" then return end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, content)
    if not ok or type(data) ~= "table" then return end
    for k, v in pairs(data) do
        if CFG[k] ~= nil then CFG[k] = v end
    end
end

pcall(loadConfig)
local Gui = Instance.new("ScreenGui")
Gui.Name = "MenuBachzLoader"
Gui.IgnoreGuiInset = true
Gui.ResetOnSpawn = false
local ok = pcall(function() Gui.Parent = CoreGui end)
if not ok then Gui.Parent = LP:WaitForChild("PlayerGui") end

local D = (type(Drawing) == "table" and Drawing.new ~= nil)
if not D then warn("[BACHZ] No Drawing API") return end

local FovC = Drawing.new("Circle")
FovC.Thickness = 1.5
FovC.NumSides = 64
FovC.Filled = false
FovC.Color = Color3.fromRGB(0, 255, 140)
FovC.Visible = false

local Dot = Drawing.new("Circle")
Dot.Thickness = 2
Dot.NumSides = 24
Dot.Radius = 8
Dot.Filled = false
Dot.Color = Color3.fromRGB(255, 220, 0)
Dot.Visible = false

local SilentDot = Drawing.new("Circle")
SilentDot.Thickness = 2
SilentDot.NumSides = 24
SilentDot.Radius = 10
SilentDot.Filled = false
SilentDot.Color = Color3.fromRGB(255, 100, 255)
SilentDot.Visible = false

local LockText = Drawing.new("Text")
LockText.Center = true
LockText.Outline = true
LockText.Font = 2
LockText.Size = 16
LockText.Color = Color3.fromRGB(255, 60, 60)
LockText.Visible = false

local EspCache = {}
local CountText = Drawing.new("Text")
CountText.Center = true
CountText.Outline = true
CountText.Font = 2
CountText.Size = 32
CountText.Color = Color3.fromRGB(255, 60, 60)
CountText.Visible = false

local InfoText = Drawing.new("Text")
InfoText.Outline = true
InfoText.Font = 2
InfoText.Size = 14
InfoText.Color = Color3.fromRGB(0, 255, 140)
InfoText.Position = Vector2.new(20, 20)
InfoText.Visible = false

local function isAlive(p)
    if not p or not p.Character then return false end
    local h = p.Character:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function isEnemy(p)
    if p == LP then return false end
    local a, b = LP.Team, p.Team
    if a and b then return a ~= b end
    return true
end

local function w2s(pos)
    local sp, on = Cam:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), on
end

local HeadCache = {}
local function getHead(p)
    local c = p.Character
    if not c then HeadCache[p] = nil; return nil end
    local cached = HeadCache[p]
    if cached and cached.Parent and cached:IsDescendantOf(c) then
        return cached
    end
    local h = c:FindFirstChild("Head")
    if h and h:IsA("BasePart") then
        HeadCache[p] = h
        return h
    end
    for _, part in ipairs(c:GetDescendants()) do
        if part:IsA("BasePart") and part.Name:lower() == "head" then
            HeadCache[p] = part
            return part
        end
    end
    HeadCache[p] = nil
    return nil
end

local function hasLos(part, wall)
    if not wall then return true end
    local o = Cam.CFrame.Position
    local d = part.Position - o
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { LP.Character, Cam }
    local r = workspace:Raycast(o, d, rp)
    return not r or r.Instance == part
end 

local function findTarget(fov, wall)
    local best, bm = nil, math.huge
    local vp = Cam.ViewportSize
    local c = Vector2.new(vp.X / 2, vp.Y / 2)
    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) and isAlive(p) then
            local head = getHead(p)
            if head and hasLos(head, wall) then
                local sp, on = w2s(head.Position)
                if on then
                    local m = (sp - c).Magnitude
                    if m <= fov and m < bm then
                        bm = m
                        best = { plr = p, part = head, sp = sp, mag = m }
                    end
                end
            end
        end
    end
    return best
end

local aimLocked = false
local lockedTarget = nil

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimLocked = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimLocked = false
        lockedTarget = nil
    end
end)

local function doAim()
    local t
    if aimLocked and lockedTarget and isAlive(lockedTarget) then
        local head = getHead(lockedTarget)
        if head then
            local sp, on = w2s(head.Position)
            if on then
                t = { plr = lockedTarget, part = head, sp = sp }
            end
        end
        if not t then lockedTarget = nil end
    end
    if not t then
        t = findTarget(CFG.aim_fov, CFG.aim_wall)
        if aimLocked and t then lockedTarget = t.plr end
    end
    if not t or not t.part or not t.part.Parent then return end
    local targetPos = t.part.Position + Vector3.new(0, CFG.aim_head_off, 0)
    local hrp = t.plr.Character and t.plr.Character:FindFirstChild("HumanoidRootPart")
    if hrp and CFG.aim_pred > 0 then
        targetPos = targetPos + hrp.AssemblyLinearVelocity * CFG.aim_pred
    end
    local want = CFrame.lookAt(Cam.CFrame.Position, targetPos)
    if CFG.aim_smooth <= 0 then
        Cam.CFrame = want
    else
        Cam.CFrame = Cam.CFrame:Lerp(want, 1 - CFG.aim_smooth)
    end
end

local silentAim = false
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == CFG.silent_key then silentAim = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == CFG.silent_key then silentAim = false end
end)

local function doSilent()
    if not CFG.silent_enabled or not silentAim then return end
    local t = findTarget(CFG.aim_fov, CFG.aim_wall)
    if not t then return end
    local targetPos = t.part.Position
    local hrp = t.plr.Character and t.plr.Character:FindFirstChild("HumanoidRootPart")
    if hrp and CFG.aim_pred > 0 then
        targetPos = targetPos + hrp.AssemblyLinearVelocity * CFG.aim_pred
    end
    Cam.CFrame = CFrame.lookAt(Cam.CFrame.Position, targetPos)
    if CFG.silent_show then
        SilentDot.Position = t.sp
        SilentDot.Visible = true
    else
        SilentDot.Visible = false
    end
end

local spinAngle = 0
local function doSpin()
    if not CFG.spin_enabled then return end
    local ch = LP.Character
    if not ch then return end
    local hrp = ch:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    spinAngle = (spinAngle + CFG.spin_speed) % 360
    local rad = math.rad(spinAngle)
    local pos = hrp.CFrame.Position
    local dir = Vector3.new(math.cos(rad), 0, math.sin(rad))
    hrp.CFrame = CFrame.new(pos, pos + dir * 10)
end

local function ensureEsp(p)
    if EspCache[p] then return EspCache[p] end
    local c = {
        box = Drawing.new("Square"),
        line = Drawing.new("Line"),
        name = Drawing.new("Text"),
        dist = Drawing.new("Text"),
    }
    c.box.Filled = false
    c.box.Thickness = 1.5
    c.box.Color = CFG.esp_box_color
    c.line.Thickness = 1.5
    c.line.Color = CFG.esp_line_color
    c.name.Center = true
    c.name.Outline = true
    c.name.Color = Color3.fromRGB(255, 255, 255)
    c.name.Size = 13
    c.dist.Center = true
    c.dist.Outline = true
    c.dist.Color = Color3.fromRGB(255, 220, 120)
    c.dist.Size = 11
    EspCache[p] = c
    return c
end

local espCounter = 0
local fpsCounter = 0
local fpsTime = tick()
local currentFps = 0
local frameSkip = 0
local COUNT_Y = 100

RunService.Heartbeat:Connect(function()
    frameSkip = frameSkip + 1
    local doHeavy = (frameSkip % 2 == 0)

    if doHeavy then
        doSpin()
        if CFG.aim_enabled then doAim() end
        doSilent()
    end

    local vp = Cam.ViewportSize
    local c = Vector2.new(vp.X / 2, vp.Y / 2)

    if doHeavy then
        FovC.Position = c
        FovC.Radius = CFG.aim_fov
        FovC.Visible = CFG.aim_enabled and CFG.aim_show_fov

        if CFG.aim_enabled and CFG.aim_show_dot then
            local t = findTarget(CFG.aim_fov, CFG.aim_wall)
            if t then
                Dot.Position = t.sp
                Dot.Visible = true
            else
                Dot.Visible = false
            end
        else
            Dot.Visible = false
        end

        if aimLocked and lockedTarget and lockedTarget.Parent then
            LockText.Text = "LOCKED: " .. lockedTarget.Name
            LockText.Position = Vector2.new(c.X, c.Y + 40)
            LockText.Visible = true
        else
            LockText.Visible = false
        end
    end

    espCounter = 0

    local lch = LP.Character
    local lhrp = lch and lch:FindFirstChild("HumanoidRootPart")
    local lpos = lhrp and lhrp.Position

    for _, ec in pairs(EspCache) do
        ec.box.Visible = false
        ec.line.Visible = false
        ec.name.Visible = false
        ec.dist.Visible = false
    end

    local lineOrigin = Vector2.new(vp.X / 2, COUNT_Y + 20)

    if CFG.esp_enabled and lpos and doHeavy then
        for _, p in ipairs(Players:GetPlayers()) do
            if isEnemy(p) and isAlive(p) then
                local ec = ensureEsp(p)
                local ch = p.Character
                local head = getHead(p)
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")

                if head and hrp then
                    local dist = (hrp.Position - lpos).Magnitude

                    if dist <= CFG.esp_max then
                        espCounter = espCounter + 1

                        local topWorld = head.Position + Vector3.new(0, 1.5, 0)
                        local botWorld = hrp.Position - Vector3.new(0, 3, 0)

                        local topScreen, onTop = w2s(topWorld)
                        local botScreen, onBot = w2s(botWorld)

                        if onTop and onBot and topScreen.Y < botScreen.Y then
                            local boxH = botScreen.Y - topScreen.Y
                            local boxW = boxH * 0.55
                            local boxX = topScreen.X - boxW / 2
                            local boxY = topScreen.Y

                            if CFG.esp_box then
                                ec.box.Position = Vector2.new(boxX, boxY)
                                ec.box.Size = Vector2.new(boxW, boxH)
                                ec.box.Visible = true
                            end

                            if CFG.esp_line then
                                ec.line.From = lineOrigin
                                ec.line.To = Vector2.new(topScreen.X, topScreen.Y + boxH)
                                ec.line.Visible = true
                            end

                            if CFG.esp_name then
                                ec.name.Text = p.Name
                                ec.name.Position = Vector2.new(topScreen.X, boxY - 16)
                                ec.name.Visible = true
                            end

                            if CFG.esp_dist then
                                ec.dist.Text = math.floor(dist) .. "m"
                                ec.dist.Position = Vector2.new(topScreen.X, boxY + boxH + 2)
                                ec.dist.Visible = true
                            end
                        end
                    end
                end
            end
        end
    end

    if CFG.esp_enabled and CFG.esp_count then
        CountText.Text = "Enemies: " .. espCounter
        CountText.Position = Vector2.new(vp.X / 2, COUNT_Y)
        CountText.Visible = true
    else
        CountText.Visible = false
    end

    if CFG.info_enabled and ActiveTab == "info" and doHeavy then
        fpsCounter = fpsCounter + 1
        if tick() - fpsTime >= 1 then
            currentFps = fpsCounter
            fpsCounter = 0
            fpsTime = tick()
        end
        local lines = {}
        table.insert(lines, "── cre bachz ──")
        if CFG.info_show_players then
            local total, alive = 0, 0
            for _, p in ipairs(Players:GetPlayers()) do
                total = total + 1
                if isAlive(p) then alive = alive + 1 end
            end
            table.insert(lines, "Players: " .. alive .. "/" .. total)
        end
        if CFG.info_show_fps then table.insert(lines, "FPS: " .. currentFps) end
        if CFG.info_show_ping then
            local ping = 0
            pcall(function() ping = math.floor(Players:GetNetworkPing(LP) * 1000) end)
            table.insert(lines, "Ping: " .. ping .. "ms")
        end
        if CFG.info_show_time then table.insert(lines, "Time: " .. os.date("%H:%M:%S")) end
        if CFG.info_show_velocity then
            local speed = lhrp and math.floor(lhrp.AssemblyLinearVelocity.Magnitude) or 0
            table.insert(lines, "Speed: " .. speed)
        end
        table.insert(lines, "Enemies: " .. espCounter)
        table.insert(lines, "")
        table.insert(lines, "── KEY ──")
        local sessionTime = math.floor(tick() - KEY_START)
        local sh = math.floor(sessionTime / 3600)
        local sm = math.floor((sessionTime % 3600) / 60)
        local ss = sessionTime % 60
        local sessionStr
        if sh > 0 then
            sessionStr = string.format("%dh %02dm %02ds", sh, sm, ss)
        elseif sm > 0 then
            sessionStr = string.format("%dm %02ds", sm, ss)
        else
            sessionStr = ss .. "s"
        end
        table.insert(lines, "Key hạn: " .. KEY_INFO)
        table.insert(lines, "Đã chơi: " .. sessionStr)
        InfoText.Text = table.concat(lines, "\n")
        InfoText.Visible = true
    else
        InfoText.Visible = false
    end
end)

--== UI ==--
local Open = Instance.new("TextButton", Gui)
Open.Size = UDim2.new(0, 60, 0, 60)
Open.Position = UDim2.new(0, 20, 0.5, -30)
Open.BackgroundColor3 = Color3.fromRGB(6, 10, 14)
Open.Text = "BZ"
Open.TextColor3 = Color3.fromRGB(0, 255, 140)
Open.TextSize = 16
Open.Font = Enum.Font.GothamBlack
Open.BorderSizePixel = 0
Open.Active = true
Open.AutoButtonColor = false
Instance.new("UICorner", Open).CornerRadius = UDim.new(1, 0)
local oStroke = Instance.new("UIStroke", Open)
oStroke.Color = Color3.fromRGB(0, 255, 140)
oStroke.Thickness = 2

local M = Instance.new("Frame", Gui)
M.Size = UDim2.new(0, 280, 0, 460)
M.Position = UDim2.new(0.5, -140, 0.5, -230)
M.BackgroundColor3 = Color3.fromRGB(6, 10, 14)
M.BorderSizePixel = 0
M.Active = true
M.Visible = false
Instance.new("UICorner", M).CornerRadius = UDim.new(0, 12)
local mStroke = Instance.new("UIStroke", M)
mStroke.Color = Color3.fromRGB(0, 255, 140)
mStroke.Thickness = 1.5

local T = Instance.new("TextLabel", M)
T.Size = UDim2.new(1, 0, 0, 34)
T.BackgroundColor3 = Color3.fromRGB(12, 18, 24)
T.BorderSizePixel = 0
T.Text = "  BACHZ · MENU"
T.TextColor3 = Color3.fromRGB(0, 255, 140)
T.Font = Enum.Font.GothamBlack
T.TextSize = 12
T.TextXAlignment = Enum.TextXAlignment.Left
Instance.new("UICorner", T).CornerRadius = UDim.new(0, 12)

local TabBar = Instance.new("Frame", M)
TabBar.Size = UDim2.new(1, -16, 0, 32)
TabBar.Position = UDim2.new(0, 8, 0, 40)
TabBar.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
TabBar.BorderSizePixel = 0
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 8)

local tabLayout = Instance.new("UIListLayout", TabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 4)

local ContentWrap = Instance.new("Frame", M)
ContentWrap.Size = UDim2.new(1, -16, 1, -120)
ContentWrap.Position = UDim2.new(0, 8, 0, 80)
ContentWrap.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
ContentWrap.BorderSizePixel = 0
ContentWrap.ClipsDescendants = true
Instance.new("UICorner", ContentWrap).CornerRadius = UDim.new(0, 8)

local Scroll = Instance.new("ScrollingFrame", ContentWrap)
Scroll.Size = UDim2.new(1, 0, 1, 0)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 140)
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.ScrollingDirection = Enum.ScrollingDirection.Y

local scrollLayout = Instance.new("UIListLayout", Scroll)
scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
scrollLayout.Padding = UDim.new(0, 4)

local scrollPad = Instance.new("UIPadding", Scroll)
scrollPad.PaddingTop = UDim.new(0, 6)
scrollPad.PaddingBottom = UDim.new(0, 6)
scrollPad.PaddingLeft = UDim.new(0, 6)
scrollPad.PaddingRight = UDim.new(0, 6)

local Sig = Instance.new("TextLabel", M)
Sig.Size = UDim2.new(1, 0, 0, 20)
Sig.Position = UDim2.new(0, 0, 1, -20)
Sig.BackgroundTransparency = 1
Sig.Text = "cre bachz"
Sig.TextColor3 = Color3.fromRGB(0, 255, 140)
Sig.Font = Enum.Font.GothamBold
Sig.TextSize = 10
Sig.TextXAlignment = Enum.TextXAlignment.Right

local Tabs = {}
local ActiveTab = nil
local TabButtons = {}

local function switchTab(name)
    if ActiveTab == name then return end
    ActiveTab = name
    for tabName, page in pairs(Tabs) do
        page.Visible = (tabName == name)
    end
    for tabName, btn in pairs(TabButtons) do
        if tabName == name then
            btn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
            btn.TextColor3 = Color3.fromRGB(160, 170, 180)
        end
    end
end

local function createTab(name, label)
    local btn = Instance.new("TextButton", TabBar)
    btn.Size = UDim2.new(1/3, -3, 1, -4)
    btn.Position = UDim2.new(0, 0, 0, 2)
    btn.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextColor3 = Color3.fromRGB(160, 170, 180)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.LayoutOrder = #TabButtons
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function() switchTab(name) end)
    TabButtons[name] = btn

    local page = Instance.new("Frame", Scroll)
    page.Size = UDim2.new(1, 0, 0, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.AutomaticSize = Enum.AutomaticSize.Y

    local pageLayout = Instance.new("UIListLayout", page)
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Padding = UDim.new(0, 4)

    Tabs[name] = page
    return page
end

local function section(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(255, 220, 0)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = #parent:GetChildren()
    return lbl
end

local function toggle(parent, name, def, cb)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(1, 0, 0, 30)
    b.BackgroundColor3 = Color3.fromRGB(16, 22, 30)
    b.BorderSizePixel = 0
    b.Text = ""
    b.AutoButtonColor = false
    b.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)

    local l = Instance.new("TextLabel", b)
    l.Size = UDim2.new(0.72, 0, 1, 0)
    l.Position = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = name
    l.TextColor3 = Color3.fromRGB(230, 235, 240)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left

    local s = def
    local ind = Instance.new("Frame", b)
    ind.Size = UDim2.new(0, 34, 0, 16)
    ind.Position = UDim2.new(1, -44, 0.5, -8)
    ind.BackgroundColor3 = s and Color3.fromRGB(0,255,140) or Color3.fromRGB(35,45,55)
    ind.BorderSizePixel = 0
    Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)

    local k = Instance.new("Frame", ind)
    k.Size = UDim2.new(0, 12, 0, 12)
    k.Position = UDim2.new(0, s and 18 or 3, 0.5, -6)
    k.BackgroundColor3 = Color3.fromRGB(240,240,240)
    k.BorderSizePixel = 0
    Instance.new("UICorner", k).CornerRadius = UDim.new(1, 0)

    b.MouseButton1Click:Connect(function()
        s = not s        
        ind.BackgroundColor3 = s and Color3.fromRGB(0,255,140) or Color3.fromRGB(35,45,55)
        k.Position = UDim2.new(0, s and 18 or 3, 0.5, -6)
        pcall(cb, s)
        pcall(saveConfig)
    end)
end

local function slider(parent, name, min, max, def, cb)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(1, 0, 0, 44)
    b.BackgroundColor3 = Color3.fromRGB(16, 22, 30)
    b.BorderSizePixel = 0
    b.Text = ""
    b.AutoButtonColor = false
    b.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)

    local l = Instance.new("TextLabel", b)
    l.Size = UDim2.new(0.7, 0, 0, 18)
    l.Position = UDim2.new(0, 12, 0, 4)
    l.BackgroundTransparency = 1
    l.Text = name
    l.TextColor3 = Color3.fromRGB(230, 235, 240)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left

    local val = Instance.new("TextLabel", b)
    val.Size = UDim2.new(0.28, 0, 0, 18)
    val.Position = UDim2.new(0.72, 0, 0, 4)
    val.BackgroundTransparency = 1
    val.Text = tostring(def)
    val.TextColor3 = Color3.fromRGB(0, 255, 140)
    val.Font = Enum.Font.GothamBold
    val.TextSize = 11
    val.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("Frame", b)
    track.Size = UDim2.new(1, -24, 0, 6)
    track.Position = UDim2.new(0, 12, 0, 30)
    track.BackgroundColor3 = Color3.fromRGB(35, 45, 55)
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new((def-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 255, 140)
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local dragging = false
    local function setVal(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = min + (max - min) * rel
        v = math.floor(v * 100) / 100
        fill.Size = UDim2.new(rel, 0, 1, 0)
        val.Text = tostring(v)
        pcall(cb, v)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setVal(input.Position.X)
        end
    end)
    track.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            pcall(saveConfig)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            setVal(input.Position.X)
        end
    end)
end

local aimPage = createTab("aim", "AIM")
section(aimPage, "— AIMBOT —")
toggle(aimPage, "Enable Aimbot (RMB)", CFG.aim_enabled, function(v) CFG.aim_enabled = v end)
toggle(aimPage, "Wall Check", CFG.aim_wall, function(v) CFG.aim_wall = v end)
toggle(aimPage, "Show FOV", CFG.aim_show_fov, function(v) CFG.aim_show_fov = v end)
toggle(aimPage, "Show Dot", CFG.aim_show_dot, function(v) CFG.aim_show_dot = v end)
slider(aimPage, "FOV", 10, 800, CFG.aim_fov, function(v) CFG.aim_fov = v end)
slider(aimPage, "Smooth", 0, 1, CFG.aim_smooth, function(v) CFG.aim_smooth = v end)
slider(aimPage, "Prediction", 0, 1, CFG.aim_pred, function(v) CFG.aim_pred = v end)
slider(aimPage, "Head Offset", -2, 2, CFG.aim_head_off, function(v) CFG.aim_head_off = v end)
section(aimPage, "— SILENT —")
toggle(aimPage, "Enable Silent (RMB)", CFG.silent_enabled, function(v) CFG.silent_enabled = v end)
toggle(aimPage, "Show Silent Dot", CFG.silent_show, function(v) CFG.silent_show = v end)
section(aimPage, "— SPINBOT —")
toggle(aimPage, "Enable Spin 360", CFG.spin_enabled, function(v) CFG.spin_enabled = v end)
slider(aimPage, "Spin Speed", 1, 100, CFG.spin_speed, function(v) CFG.spin_speed = v end)

local espPage = createTab("esp", "ESP")
section(espPage, "— ESP —")
toggle(espPage, "Enable ESP", CFG.esp_enabled, function(v) CFG.esp_enabled = v end)
toggle(espPage, "Line", CFG.esp_line, function(v) CFG.esp_line = v end)
toggle(espPage, "Box", CFG.esp_box, function(v) CFG.esp_box = v end)
toggle(espPage, "Name", CFG.esp_name, function(v) CFG.esp_name = v end)
toggle(espPage, "Distance", CFG.esp_dist, function(v) CFG.esp_dist = v end)
toggle(espPage, "Count", CFG.esp_count, function(v) CFG.esp_count = v end)
slider(espPage, "Max Distance", 100, 20000, CFG.esp_max, function(v) CFG.esp_max = v end)

local infoPage = createTab("info", "INFO")
section(infoPage, "— INFO OVERLAY —")
toggle(infoPage, "Enable Info", CFG.info_enabled, function(v) CFG.info_enabled = v end)
toggle(infoPage, "Show Players", CFG.info_show_players, function(v) CFG.info_show_players = v end)
toggle(infoPage, "Show FPS", CFG.info_show_fps, function(v) CFG.info_show_fps = v end)
toggle(infoPage, "Show Ping", CFG.info_show_ping, function(v) CFG.info_show_ping = v end)
toggle(infoPage, "Show Time", CFG.info_show_time, function(v) CFG.info_show_time = v end)
toggle(infoPage, "Show Velocity", CFG.info_show_velocity, function(v) CFG.info_show_velocity = v end)

switchTab("aim")

--== NÚT BZ: CLICK MỞ MENU · DRAG DI CHUYỂN ==--
do
    local dragging = false
    local dragStart, startPos
    local moved = false
    local CLICK_THRESHOLD = 5

    Open.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            startPos = Open.Position
        end
    end)

    Open.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            if dragging and not moved then
                M.Visible = not M.Visible
            end
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > CLICK_THRESHOLD or math.abs(delta.Y) > CLICK_THRESHOLD then
                moved = true
            end
            if moved then
                Open.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end
    end)
end

print("[BACHZ] MENU LOADER BY BACHZ loaded")
print("cre bachz")
