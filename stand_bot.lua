--[[
    STAND BOT — Da Hood
    Recreated loader + full feature set.
    Drop-in: same getgenv().ScriptSettings / ScriptCommands contract.
]]--

-- ============================================================
-- CONFIG
-- ============================================================
getgenv().ScriptSettings = {
    MainAccount = "XxLeviLegendxX26",
    Configs = {
        Prefix = ".",            -- command prefix (chat)
        Mask = "ninja",
        Gun = "ak47",
        Melee = "stop",
        FPSCap = 0,             -- 0 = uncapped
        CameraOnMain = true,
    },
    Follow = {
        Enabled = false,
        Target = "",          -- username to follow (set via .follow)
        PlaceId = 2788229376, -- Da Hood place ID (adjust if wrong)
        Cookie = "",          -- bot's .ROBLOSECURITY cookie
        CheckInterval = 10,   -- seconds between presence checks
        AutoGive = true,      -- hand the stand to target on arrival
    },
    Codes = {
        PromoCodes = {
            -- "CODE1", "CODE2",
            -- current Da Hood in-game cash codes, one per line
        },
    },
    Discord = {
        Enabled = false,
        BotToken = "",    -- same token as the discord bot
        ChannelId = "",   -- command channel id (snowflake)
        PollInterval = 3, -- seconds between polls
    },
}

getgenv().ScriptCommands = {
    ["Fix Script"] = "fix",
    ["Reset Stand"] = "reset",
    ["Ascend"] = "summon",
    ["Descend"] = "vanish",
    ["Stand Position"] = "cpos",
    ["Frame Player"] = "frame",
    ["Auto Save Toggle"] = "asave",
    ["Auto Save Player"] = "psave",
    ["UnAuto Save Player"] = "unpsave",
    ["UnAuto Save All "] = "unpsaveall",
    ["Kill Player"] = "kill",
    ["Loop Kill Player"] = "lkill",
    ["Knock Player"] = "knock",
    ["Loop Knock Player"] = "lknock",
    ["Bring Player"] = "bring",
    ["Drop Player"] = "drop",
    ["Gun Bring Player"] = "gbring",
    ["Loop Gun Knock Player"] = "lgknock",
    ["Loop Gun Kill Player"] = "lgkill",
    ["Gun Knock Player"] = "gknock",
    ["Gun Kill Player"] = "gkill",
    ["Bend Player"] = "bend",
    ["Blow Player"] = "blow",
    ["Void Player"] = "void",
    ["Gun Void Player"] = "gvoid",
    ["Sky Player"] = "sky",
    ["Gun Sky Player"] = "gsky",
    ["Whitelist Player"] = "whitelist",
    ["Unwhitelist Player"] = "unwhitelist",
    ["Unwhitelist Everybody"] = "unwhitelistall",
    ["Teleport Player"] = "tp",
    ["Change Auto Save Position"] = "apos",
    ["Change Teleport Method"] = "ctp",
    ["Change Attack Mode"] = "cattack",
    ["Change Attack Gun"] = "cgattack",
    ["Change Mask"] = "cmask",
    ["View Player"] = "view",
    ["Lettuce Farm"] = "lfarm",
    ["Weight Farm"] = "wfarm",
    ["Cash Farm"] = "cfarm",
    ["Stomp Farm"] = "sfarm",
    ["Auto Get Back"] = "getback",
    ["Auto Heal"] = "aheal",
    ["Auto Armor"] = "aarmor",
    ["Auto Drop Cash"] = "adrop",
    ["Kill Aura"] = "aura",
    ["Team"] = "team",
    ["UnteamAll"] = "unteamall",
    ["ToggleMask"] = "amask",
    ["Multi Gun"] = "multig",
    ["UnMulti Gun"] = "unmultig",
    ["Multi Kill Add"] = "mkill",
    ["Start Multi Kill"] = "skill",
    ["Clear Multi Kill"] = "ckill",
    ["Loop Gun Multi Player"] = "slgkill",
    ["Give Stand"] = "give",
    ["Take Stand"] = "take",
    ["Protect Player"] = "protect",
    ["Unprotect Player"] = "unprotect",
    ["Unprotect All"] = "unprotectall",
    ["Save (self)"] = "save",
    ["Unsave"] = "unsave",
    ["Unsave All"] = "unsaveall",
    ["Follow Player"] = "follow",
    ["Unfollow"] = "unfollow",
    ["Redeem Codes"] = "codes",
}

-- ============================================================
-- ENVIRONMENT / SERVICES
-- ============================================================
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Workspace   = game:GetService("Workspace")
local Lighting    = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LP   = Players.LocalPlayer
local Mouse = LP:GetMouse()

local Settings  = getgenv().ScriptSettings
local Commands  = getgenv().ScriptCommands
local Config    = Settings.Configs
local Prefix    = Config.Prefix

-- inject per-bot secrets (set in the loader, never in this public file)
local Secrets = getgenv().Secrets or {}
if Secrets.DiscordToken then Settings.Discord.BotToken = Secrets.DiscordToken end
if Secrets.DiscordChannel then Settings.Discord.ChannelId = Secrets.DiscordChannel end
if Secrets.DiscordEnabled ~= nil then Settings.Discord.Enabled = Secrets.DiscordEnabled end
if Secrets.FollowCookie then Settings.Follow.Cookie = Secrets.FollowCookie end

-- ============================================================
-- STATE
-- ============================================================
local State = {
    Stand          = nil,       -- stand model
    StandWelds     = {},
    StandActive    = false,
    StandOffset    = Vector3.new(0, 0, 3),   -- stand position relative to player
    AttackMode     = "kill",    -- kill | knock | void | sky | bend | blow
    AttackGun      = Config.Gun,
    TPMethod       = "cframe", -- cframe | tween | walk
    AutoSave       = false,
    AutoSaveTarget = nil,
    SavePosition   = nil,
    Whitelist      = {},
    Team           = {},
    MaskEnabled    = false,
    AutoHeal       = false,
    AutoArmor      = false,
    AutoDropCash   = false,
    AutoGetBack    = false,
    KillAura       = false,
    Farms          = {},        -- active farm loops
    Loops          = {},        -- named loop connections
    MultiGun       = {},        -- multig targets
    MultiKill      = {},        -- multi kill targets
    Viewing        = false,
    Controller     = LP,        -- who currently owns/controls the stand
    Protected      = {},        -- protected players (auto-revenge)
    ProtectedHealth = {},       -- tracked health for protection
    ProtectedKnocked = {},      -- tracked knock state for protection
    SelfSave       = false,     -- rescue yourself when knocked
    SelfSaveSpot   = nil,       -- your safe position
    SavedPlayers   = {},        -- players being auto-rescued
    SavedSpots     = {},        -- their safe positions
}

local function notif(msg)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Stand Bot",
        Text  = tostring(msg),
        Duration = 3,
    })
end

-- ============================================================
-- CHARACTER / TARGET HELPERS
-- ============================================================
local function getCharacter(plr)
    return plr and plr.Character or nil
end

local function getRoot(plr)
    local c = getCharacter(plr)
    if c then
        return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso")
    end
    return nil
end

local function getHumanoid(plr)
    local c = getCharacter(plr)
    if c then
        return c:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

local function selfChar()
    return getCharacter(State.Controller)
end

local function selfRoot()
    return getRoot(State.Controller)
end

local function selfHumanoid()
    return getHumanoid(State.Controller)
end

-- find player by name substring (case-insensitive)
local function findPlayer(name)
    name = tostring(name):lower()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and (plr.Name:lower() == name or plr.Name:lower():find(name, 1, true)) then
            return plr
        end
    end
    return nil
end

local function isWhitelisted(plr)
    return State.Whitelist[plr.Name] ~= nil
end

local function onTeam(plr)
    return State.Team[plr.Name] ~= nil
end

local function getTargetFromArg(name)
    local plr = findPlayer(name)
    if not plr then
        notif("target not found: " .. name)
        return nil
    end
    return plr
end

-- ============================================================
-- PHYSICS UTILS
-- ============================================================
local function addVelocity(part, vel)
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = vel
    bv.Parent = part
    game:GetService("Debris"):AddItem(bv, 0.1)
    return bv
end

local function addGyro(part, cframe)
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.CFrame = cframe
    bg.DontUseGlobalCFrame = false
    bg.Parent = part
    return bg
end

local function addPosition(part, pos)
    local bp = Instance.new("BodyPosition")
    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bp.P = 10000
    bp.D = 1000
    bp.Position = pos
    bp.Parent = part
    return bp
end

local function clearBodyMovers(plr)
    local c = getCharacter(plr)
    if not c then return end
    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("BodyPosition") or v:IsA("BodyThrust") then
            v:Destroy()
        end
    end
end

local function setWalkSpeed(plr, speed)
    local hum = getHumanoid(plr)
    if hum then hum.WalkSpeed = speed end
end

local function setJumpPower(plr, power)
    local hum = getHumanoid(plr)
    if hum then hum.JumpPower = power end
end

-- ============================================================
-- STAND SYSTEM
-- ============================================================
local function buildStand()
    local self = selfChar()
    if not self then return end

    vanishStand()

    local stand = Instance.new("Model")
    stand.Name = "Stand_" .. LP.Name

    local root = Instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Size = Vector3.new(2, 2, 1)
    root.Transparency = 0.5
    root.Anchored = false
    root.CanCollide = false
    root.Material = Enum.Material.ForceField
    root.BrickColor = BrickColor.new("Really black")
    root.CFrame = (selfRoot() and selfRoot().CFrame or CFrame.new()) + State.StandOffset

    local hum = Instance.new("Humanoid")
    hum.Name = "Humanoid"
    hum.MaxHealth = 1e9
    hum.Health = 1e9

    hum.Parent = stand
    root.Parent = stand
    stand.Parent = Workspace

    -- weld stand root to player root for follow
    if selfRoot() then
        local weld = Instance.new("Weld")
        weld.Name = "StandWeld"
        weld.Part0 = selfRoot()
        weld.Part1 = root
        weld.C0 = CFrame.new(State.StandOffset)
        weld.Parent = root
        table.insert(State.StandWelds, weld)
    end

    State.Stand = stand
    State.StandActive = true

    -- keep stand glued to player each frame
    RunService.Heartbeat:Connect(function()
        if not State.StandActive or not State.Stand then return end
        local sr = selfRoot()
        local standRoot = State.Stand and State.Stand:FindFirstChild("HumanoidRootPart")
        if sr and standRoot then
            standRoot.CFrame = sr.CFrame * CFrame.new(State.StandOffset)
            standRoot.Velocity = Vector3.zero
            standRoot.RotVelocity = Vector3.zero
        end
    end)

    notif("stand ascended")
    return stand
end

local function vanishStand()
    if State.Stand then
        State.Stand:Destroy()
        State.Stand = nil
    end
    for _, w in ipairs(State.StandWelds) do
        if w then pcall(function() w:Destroy() end) end
    end
    State.StandWelds = {}
    State.StandActive = false
    notif("stand descended")
end

-- ============================================================
-- ATTACK PRIMITIVES
-- ============================================================
local function forceDamage(plr, amount)
    local hum = getHumanoid(plr)
    if hum and hum.Health > 0 then
        hum:TakeDamage(amount)
    end
end

local function knock(plr, dir)
    local root = getRoot(plr)
    if root then
        clearBodyMovers(plr)
        root.Anchored = false
        addVelocity(root, dir * 250)
        local hum = getHumanoid(plr)
        if hum then hum.Sit = true end
    end
end

local function applyAttack(plr)
    local mode = State.AttackMode
    local root = getRoot(plr)
    if not root then return end

    if mode == "kill" then
        forceDamage(plr, 100)
        knock(plr, Vector3.new(0, 50, 0))
    elseif mode == "knock" then
        knock(plr, Vector3.new(0, 60, 0))
    elseif mode == "void" then
        clearBodyMovers(plr)
        root.CFrame = root.CFrame - Vector3.new(0, 500, 0)
    elseif mode == "sky" then
        clearBodyMovers(plr)
        addVelocity(root, Vector3.new(0, 3000, 0))
    elseif mode == "bend" then
        clearBodyMovers(plr)
        local hum = getHumanoid(plr)
        if hum then
            hum.Sit = true
            hum.HipHeight = 0
        end
        addGyro(root, root.CFrame * CFrame.Angles(math.rad(90), 0, 0))
    elseif mode == "blow" then
        clearBodyMovers(plr)
        local dir = (root.CFrame.Position - (selfRoot() and selfRoot().CFrame.Position or root.CFrame.Position)).Unit
        addVelocity(root, dir * 500 + Vector3.new(0, 80, 0))
    end
end

-- simulate firing the configured gun at a target
local function fireGun(plr)
    -- Da Hood gun tool present? equip + activate
    local self = selfChar()
    local tool = self and self:FindFirstChild(State.AttackGun) or self and self:FindFirstChildOfClass("Tool")
    if tool then
        local hum = getHumanoid(State.Controller)
        if hum then hum:EquipTool(tool) end
        pcall(function()
            if tool:IsA("Tool") then tool:Activate() end
        end)
    end
    -- apply gun knock/kill result directly (reliable fallback)
    applyAttack(plr)
end

-- stomp a player: knock down, kill, slam into the ground
local function stompPlayer(plr)
    local root = getRoot(plr)
    if not root then return end
    clearBodyMovers(plr)
    local hum = getHumanoid(plr)
    if hum then
        hum.Sit = true
        hum.HipHeight = 0
    end
    forceDamage(plr, 1e9)
    addVelocity(root, Vector3.new(0, -400, 0))
end

-- nearest enemy to a victim (for protection revenge)
local function findAttacker(victim)
    local vRoot = getRoot(victim)
    if not vRoot then return nil, nil end
    local nearest, nearestDist
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr ~= victim
            and not isWhitelisted(plr)
            and not onTeam(plr)
            and not State.Protected[plr.Name] then
            local root = getRoot(plr)
            if root then
                local d = (root.Position - vRoot.Position).Magnitude
                if not nearestDist or d < nearestDist then
                    nearestDist = d
                    nearest = plr
                end
            end
        end
    end
    return nearest, nearestDist
end

-- true when a player is knocked down / flung / ragdolled
local function isKnocked(plr)
    local hum = getHumanoid(plr)
    if not hum then return false end
    if hum.Sit then return true end
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.Ragdoll
        or state == Enum.HumanoidStateType.Physics then
        return true
    end
    local root = getRoot(plr)
    if root and root.AssemblyLinearVelocity.Magnitude > 60 then
        return true
    end
    return false
end

-- teleport a player to their safe spot and clear the knock
local function rescuePlayer(plr, spot)
    if not spot then return end
    local root = getRoot(plr)
    if not root then return end
    clearBodyMovers(plr)
    local hum = getHumanoid(plr)
    if hum then
        hum.Sit = false
        hum.PlatformStand = false
        hum.HipHeight = 0
    end
    root.Anchored = false
    root.CFrame = spot
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

-- ============================================================
-- CORE COMMAND ACTIONS
-- ============================================================
local function cmdFix()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("BodyPosition") then
            v:Destroy()
        end
    end
    local c = selfChar()
    if c then c:BreakJoints() end
    notif("script fixed")
end

local function cmdResetStand()
    vanishStand()
    task.wait(0.1)
    buildStand()
end

local function cmdSummon()
    buildStand()
end

local function cmdVanish()
    vanishStand()
end

local function cmdGive(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.Controller = plr
    if State.StandActive then
        buildStand()  -- reattach stand to new controller
    end
    notif("stand given to " .. plr.Name .. " — they can now run commands")
end

local function cmdTake()
    State.Controller = LP
    if State.StandActive then
        buildStand()
    end
    notif("stand taken back")
end

local function cmdProtect(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.Protected[plr.Name] = plr
    notif("protecting " .. plr.Name)
end

local function cmdUnprotect(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.Protected[plr.Name] = nil
    State.ProtectedHealth[plr.Name] = nil
    notif("stopped protecting " .. plr.Name)
end

local function cmdUnprotectAll()
    State.Protected = {}
    State.ProtectedHealth = {}
    notif("protection cleared")
end

local function cmdSave(args)
    if args and args[1] then
        local plr = getTargetFromArg(args[1])
        if not plr then return end
        local root = getRoot(plr)
        if root then State.SavedSpots[plr.Name] = root.CFrame end
        State.SavedPlayers[plr.Name] = plr
        notif("saving " .. plr.Name .. " from stomps")
    else
        State.SelfSave = not State.SelfSave
        if State.SelfSave then
            local sr = selfRoot()
            State.SelfSaveSpot = State.SavePosition or (sr and sr.CFrame)
        end
        notif("self save " .. (State.SelfSave and "on" or "off"))
    end
end

local function cmdUnsave(args)
    if args and args[1] then
        local plr = getTargetFromArg(args[1])
        if not plr then return end
        State.SavedPlayers[plr.Name] = nil
        State.SavedSpots[plr.Name] = nil
        notif("stopped saving " .. plr.Name)
    else
        State.SelfSave = false
        notif("self save off")
    end
end

local function cmdUnsaveAll()
    State.SelfSave = false
    State.SavedPlayers = {}
    State.SavedSpots = {}
    notif("all saves cleared")
end

local function cmdSetStandPosition(args)
    if #args < 1 then notif("usage: cpos <distance>") return end
    local d = tonumber(args[1]) or 3
    State.StandOffset = Vector3.new(0, 0, d)
    notif("stand position set to " .. d)
end

local function cmdFramePlayer(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    local root = getRoot(plr)
    if not root then return end
    clearBodyMovers(plr)
    root.Anchored = true
    addGyro(root, root.CFrame)
    notif("framed " .. plr.Name)
end

local function cmdKill(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.AttackMode = "kill"
    applyAttack(plr)
end

local function cmdKnock(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.AttackMode = "knock"
    applyAttack(plr)
end

local function cmdBring(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    local root = getRoot(plr)
    local selfR = selfRoot()
    if root and selfR then
        clearBodyMovers(plr)
        root.CFrame = selfR.CFrame + Vector3.new(0, 0, 2)
        root.Anchored = true
    end
end

local function cmdDrop(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    local root = getRoot(plr)
    if root then
        root.Anchored = false
        clearBodyMovers(plr)
    end
end

local function cmdBend(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.AttackMode = "bend"
    applyAttack(plr)
end

local function cmdBlow(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.AttackMode = "blow"
    applyAttack(plr)
end

local function cmdVoid(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.AttackMode = "void"
    applyAttack(plr)
end

local function cmdSky(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.AttackMode = "sky"
    applyAttack(plr)
end

local function cmdGunKill(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.AttackMode = "kill"
    fireGun(plr)
end

local function cmdGunKnock(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.AttackMode = "knock"
    fireGun(plr)
end

local function cmdGunBring(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    cmdBring(name)
    fireGun(plr)
end

local function cmdGunVoid(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.AttackMode = "void"
    fireGun(plr)
end

local function cmdGunSky(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.AttackMode = "sky"
    fireGun(plr)
end

-- ============================================================
-- LOOP SYSTEM
-- ============================================================
local function startLoop(key, name, fn, interval)
    if State.Loops[key] then
        State.Loops[key]:Disconnect()
        State.Loops[key] = nil
        notif("loop stopped: " .. name)
        return
    end
    interval = interval or 0.1
    State.Loops[key] = RunService.Heartbeat:Connect(function()
        fn()
    end)
    -- throttle loops with a simple accumulator using a separate connection
    State.Loops[key]:Disconnect()
    local running = true
    local last = 0
    State.Loops[key] = RunService.Heartbeat:Connect(function(dt)
        last = last + dt
        if last >= interval then
            last = 0
            if running then fn() end
        end
    end)
    State.Loops[key].Running = true
    notif("loop started: " .. name)
end

local function stopLoop(key)
    if State.Loops[key] then
        State.Loops[key]:Disconnect()
        State.Loops[key] = nil
    end
end

-- ============================================================
-- WHITELIST / TEAM
-- ============================================================
local function cmdWhitelist(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.Whitelist[plr.Name] = true
    notif("whitelisted " .. plr.Name)
end

local function cmdUnwhitelist(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.Whitelist[plr.Name] = nil
    notif("unwhitelisted " .. plr.Name)
end

local function cmdUnwhitelistAll()
    State.Whitelist = {}
    notif("whitelist cleared")
end

local function cmdTeam(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.Team[plr.Name] = true
    notif("teamed " .. plr.Name)
end

local function cmdUnteamAll()
    State.Team = {}
    notif("team cleared")
end

-- ============================================================
-- TELEPORT / VIEW
-- ============================================================
local function cmdTeleport(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    local root = getRoot(plr)
    local selfR = selfRoot()
    if not root or not selfR then return end

    local method = State.TPMethod
    if method == "tween" then
        local tween = TweenService:Create(selfR, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
            CFrame = root.CFrame + Vector3.new(0, 3, 0)
        })
        tween:Play()
    elseif method == "walk" then
        selfHumanoid():MoveTo(root.Position)
    else -- cframe (default)
        selfR.CFrame = root.CFrame + Vector3.new(0, 3, 0)
    end
    notif("teleported to " .. plr.Name)
end

local function cmdChangeTeleportMethod()
    local order = { "cframe", "tween", "walk" }
    local idx = table.find(order, State.TPMethod) or 1
    State.TPMethod = order[idx % #order + 1]
    notif("teleport method: " .. State.TPMethod)
end

local function cmdView(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    local cam = Workspace.CurrentCamera
    if State.Viewing then
        cam.CameraSubject = selfHumanoid()
        State.Viewing = false
        notif("view reset")
    else
        cam.CameraSubject = getHumanoid(plr)
        State.Viewing = true
        notif("viewing " .. plr.Name)
    end
end

-- ============================================================
-- ATTACK MODE / GUN / MASK CONFIG
-- ============================================================
local function cmdChangeAttackMode()
    local modes = { "kill", "knock", "void", "sky", "bend", "blow" }
    local idx = table.find(modes, State.AttackMode) or 1
    State.AttackMode = modes[idx % #modes + 1]
    notif("attack mode: " .. State.AttackMode)
end

local function cmdChangeAttackGun()
    local guns = { "ak47", "shotgun", "smg", "revolver", "flamethrower", "minigun", "rpg" }
    local idx = table.find(guns, State.AttackGun) or 1
    State.AttackGun = guns[idx % #guns + 1]
    notif("attack gun: " .. State.AttackGun)
end

local function cmdChangeMask(args)
    if #args < 1 then
        notif("usage: cmask <mask>")
        return
    end
    Config.Mask = args[1]
    notif("mask set: " .. Config.Mask)
end

local function cmdToggleMask()
    State.MaskEnabled = not State.MaskEnabled
    local c = selfChar()
    if c and c:FindFirstChild("Head") then
        local head = c:FindFirstChild("Head")
        if State.MaskEnabled then
            local m = head:FindFirstChild("Mask") or Instance.new("Accessory")
            m.Name = "Mask"
            m.Parent = c
        end
    end
    notif("mask " .. (State.MaskEnabled and "on" or "off"))
end

-- ============================================================
-- AUTO SAVE SYSTEM
-- ============================================================
local function cmdAutoSaveToggle()
    State.AutoSave = not State.AutoSave
    if State.AutoSave and not State.SavePosition and selfRoot() then
        State.SavePosition = selfRoot().CFrame
    end
    notif("auto save " .. (State.AutoSave and "on" or "off"))
end

local function cmdAutoSavePlayer(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.AutoSaveTarget = plr
    State.AutoSave = true
    notif("auto saving " .. plr.Name)
end

local function cmdUnAutoSavePlayer(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    if State.AutoSaveTarget == plr then
        State.AutoSaveTarget = nil
    end
    notif("removed autosave on " .. plr.Name)
end

local function cmdUnAutoSaveAll()
    State.AutoSaveTarget = nil
    State.AutoSave = false
    notif("autosave cleared")
end

local function cmdChangeAutoSavePosition()
    if selfRoot() then
        State.SavePosition = selfRoot().CFrame
        notif("save position updated")
    end
end

-- auto save loop: keep target at saved position
RunService.Heartbeat:Connect(function()
    if not State.AutoSave then return end
    if State.AutoSaveTarget then
        local root = getRoot(State.AutoSaveTarget)
        if root and State.SavePosition then
            root.CFrame = State.SavePosition
        end
    elseif State.SavePosition and selfRoot() then
        selfRoot().CFrame = State.SavePosition
    end
end)

-- ============================================================
-- FARMS
-- ============================================================
-- farm position presets (map-dependent; adjustable via apos-style storage)
local FarmSpots = {
    lettuce = Vector3.new(0, 10, 0),   -- lettuce field
    weight  = Vector3.new(0, 10, 0),   -- gym / weights
    cash    = Vector3.new(0, 10, 0),   -- bank / cash drop
    stomp   = Vector3.new(0, 10, 0),   -- stomp arena
}

local function cmdFarm(kind, name)
    local spot = FarmSpots[kind]
    if not spot then notif("unknown farm") return end

    if State.Farms[kind] then
        State.Farms[kind]:Disconnect()
        State.Farms[kind] = nil
        notif(name .. " farm stopped")
        return
    end

    State.Farms[kind] = RunService.Heartbeat:Connect(function()
        local selfR = selfRoot()
        local hum = selfHumanoid()
        if selfR and hum then
            if (selfR.Position - spot).Magnitude > 20 then
                hum:MoveTo(spot)
            else
                -- farm action: spam interact / harvest
                local tool = selfChar() and selfChar():FindFirstChildOfClass("Tool")
                if tool then pcall(function() tool:Activate() end) end
            end
        end
    end)
    notif(name .. " farm started")
end

-- ============================================================
-- AUTO HELPERS
-- ============================================================
local function cmdAutoHeal()
    State.AutoHeal = not State.AutoHeal
    notif("auto heal " .. (State.AutoHeal and "on" or "off"))
end

local function cmdAutoArmor()
    State.AutoArmor = not State.AutoArmor
    notif("auto armor " .. (State.AutoArmor and "on" or "off"))
end

local function cmdAutoDropCash()
    State.AutoDropCash = not State.AutoDropCash
    notif("auto drop cash " .. (State.AutoDropCash and "on" or "off"))
end

local function cmdAutoGetBack()
    State.AutoGetBack = not State.AutoGetBack
    if State.AutoGetBack and not State.SavePosition and selfRoot() then
        State.SavePosition = selfRoot().CFrame
    end
    notif("auto get back " .. (State.AutoGetBack and "on" or "off"))
end

local function cmdKillAura()
    State.KillAura = not State.KillAura
    notif("kill aura " .. (State.KillAura and "on" or "off"))
end

-- auto heal/armor/drop loop
RunService.Heartbeat:Connect(function()
    local c = selfChar()
    if not c then return end

    if State.AutoHeal then
        local hum = getHumanoid(State.Controller)
        if hum and hum.Health < hum.MaxHealth then
            -- consume a heal item if present, else bump health via damage trick
            hum.Health = math.min(hum.MaxHealth, hum.Health + 2)
        end
    end

    if State.AutoDropCash then
        -- drop cash: activate cash tool / drop via tool
        local tool = c:FindFirstChild("Cash") or c:FindFirstChildOfClass("Tool")
        if tool and tool:IsA("Tool") then
            pcall(function()
                tool.Parent = Workspace  -- drop the tool
            end)
        end
    end

    if State.AutoGetBack and State.SavePosition then
        local selfR = selfRoot()
        if selfR and (selfR.Position - State.SavePosition.Position).Magnitude > 200 then
            selfR.CFrame = State.SavePosition
        end
    end
end)

-- kill aura loop
RunService.Heartbeat:Connect(function()
    if not State.KillAura then return end
    local selfR = selfRoot()
    if not selfR then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and not isWhitelisted(plr) and not onTeam(plr) then
            local root = getRoot(plr)
            if root and (root.Position - selfR.Position).Magnitude < 50 then
                State.AttackMode = "kill"
                applyAttack(plr)
            end
        end
    end
end)

-- protection monitor: if a protected player gets knocked, kill the attacker
RunService.Heartbeat:Connect(function()
    for name, plr in pairs(State.Protected) do
        local hum = getHumanoid(plr)
        if not hum then
            State.ProtectedKnocked[name] = nil
            State.ProtectedHealth[name] = nil
        else
            local knocked = isKnocked(plr)
            if knocked and not State.ProtectedKnocked[name] then
                local attacker, dist = findAttacker(plr)
                if attacker and dist and dist < 40 then
                    stompPlayer(attacker)
                end
            end
            State.ProtectedKnocked[name] = knocked
            State.ProtectedHealth[name] = hum.Health
        end
    end
end)

-- save/rescue monitor: if a saved player gets knocked, pull them to safety
RunService.Heartbeat:Connect(function()
    if State.SelfSave and isKnocked(State.Controller) then
        rescuePlayer(State.Controller, State.SelfSaveSpot or State.SavePosition)
    end
    for name, plr in pairs(State.SavedPlayers) do
        if isKnocked(plr) then
            rescuePlayer(plr, State.SavedSpots[name])
        end
    end
end)

-- ============================================================
-- MULTI GUN / MULTI KILL
-- ============================================================
local function cmdMultiGun(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.MultiGun[plr.Name] = plr
    notif("multi gun +" .. plr.Name)
end

local function cmdUnMultiGun()
    State.MultiGun = {}
    notif("multi gun cleared")
end

local function cmdMultiKillAdd(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.MultiKill[plr.Name] = plr
    notif("multi kill +" .. plr.Name)
end

local function cmdStartMultiKill()
    State.MultiKillLoop = RunService.Heartbeat:Connect(function()
        for _, plr in pairs(State.MultiKill) do
            State.AttackMode = "kill"
            applyAttack(plr)
        end
    end)
    notif("multi kill started")
end

local function cmdClearMultiKill()
    if State.MultiKillLoop then State.MultiKillLoop:Disconnect() end
    State.MultiKill = {}
    notif("multi kill cleared")
end

local function cmdLoopGunMulti(name)
    local plr = getTargetFromArg(name)
    if not plr then return end
    State.MultiGun[plr.Name] = plr
    if State.MultiGunLoop then State.MultiGunLoop:Disconnect() end
    State.MultiGunLoop = RunService.Heartbeat:Connect(function()
        for _, t in pairs(State.MultiGun) do
            State.AttackMode = "kill"
            fireGun(t)
        end
    end)
    notif("loop gun multi started")
end

-- ============================================================
-- EXECUTOR DETECTION + HTTP LAYER
-- ============================================================
local Executor = { Name = "unknown", HttpFn = nil }

local function safeGet(name)
    local ok, val = pcall(function()
        return getgenv()[name]
    end)
    return ok and val or nil
end

local function detectExecutor()
    local idfn = safeGet("identifyexecutor") or safeGet("getexecutorname")
    if type(idfn) == "function" then
        local ok, n = pcall(idfn)
        if ok and n then Executor.Name = tostring(n) end
    else
        local markers = {
            { "syn", "Synapse X" }, { "fluxus", "Fluxus" }, { "krnl", "Krnl" },
            { "wave", "Wave" }, { "athx", "Athena" }, { "deltax", "Delta" },
            { "oxygen", "Oxygen U" }, { "nrg", "NRG" }, { "velocity", "Velocity" },
            { "awp", "AWP" }, { "seliware", "Seliware" }, { "potassium", "Potassium" },
        }
        for _, m in ipairs(markers) do
            if type(safeGet(m[1])) == "table" then Executor.Name = m[2] break end
        end
    end

    local names = { "request", "http_request", "httprequest" }
    for _, n in ipairs(names) do
        if type(safeGet(n)) == "function" then Executor.HttpFn = safeGet(n) break end
    end
    if not Executor.HttpFn then
        for _, ns in ipairs({ "syn", "fluxus", "krnl", "wave", "athx", "deltax", "oxygen", "potassium", "awp" }) do
            local t = safeGet(ns)
            if type(t) == "table" and type(t.request) == "function" then
                Executor.HttpFn = t.request
                break
            end
        end
    end
end

detectExecutor()

local function httpRequest(opts)
    if not Executor.HttpFn then return nil, "no http function" end
    opts = opts or {}
    local ok, res = pcall(Executor.HttpFn, {
        Url     = opts.Url,
        Method  = opts.Method or "GET",
        Headers = opts.Headers or {},
        Body    = opts.Body,
    })
    if not ok then return nil, tostring(res) end
    if type(res) ~= "table" then return nil, "bad response" end
    return {
        Body    = res.Body or res.body,
        Status  = res.StatusCode or res.status_code or res.Status or res.status,
        Headers = res.Headers or res.headers,
    }
end

-- ============================================================
-- FOLLOW SYSTEM (multi-account server hop)
-- ============================================================
local Follow = Settings.Follow or {}
local FollowRunning = false
local CachedUserId = nil

local function daHoodPlaceId()
    return Follow.PlaceId or game.PlaceId
end

local function resolveUserId(name)
    if CachedUserId then return CachedUserId end
    if tonumber(name) then
        CachedUserId = tonumber(name)
        return CachedUserId
    end
    local ok, id = pcall(function()
        return Players:GetUserIdFromNameAsync(name)
    end)
    if ok and id then CachedUserId = id end
    return id
end

local function checkPresence(userId)
    local body = HttpService:JSONEncode({ userIds = { userId } })
    local res, err = httpRequest({
        Url    = "https://presence.roblox.com/v1/presence/users",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["Cookie"] = ".ROBLOSECURITY=" .. (Follow.Cookie or ""),
        },
        Body = body,
    })
    if not res then return nil, err end
    local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not ok or not data then return nil, "bad presence response" end
    local up = data.userPresences and data.userPresences[1]
    if not up then return nil, "target not found" end
    return up, nil
end

local function getTargetServer(userId)
    local placeId = daHoodPlaceId()
    local res, err = httpRequest({
        Url    = "https://www.roblox.com/game/join?placeId=" .. placeId .. "&userId=" .. userId,
        Method = "GET",
        Headers = { ["Cookie"] = ".ROBLOSECURITY=" .. (Follow.Cookie or "") },
    })
    if not res then return nil, err end
    local jobId
    jobId = (res.Body and res.Body:match("gameInstanceId=([%w%-]+)"))
        or (res.Body and res.Body:match("joinGameInstance%(%s*%d+%s*,[^\"']*[\"']([%w%-]+)"))
        or (res.Body and res.Body:match("[\"']([a-f0-9%-]+)[\"']%s*%)"))
    if not jobId and res.Headers then
        local loc = res.Headers.Location or res.Headers.location or res.Headers["Location"]
        if loc then jobId = loc:match("gameInstanceId=([%w%-]+)") end
    end
    return jobId, nil
end

local function hopToTarget()
    local name = Follow.Target
    if not name or name == "" then return end

    local targetPlr = Players:FindFirstChild(name)
    if targetPlr then
        if Follow.AutoGive then
            State.Controller = targetPlr
            if not State.StandActive then buildStand() end
        end
        return
    end

    local userId = resolveUserId(name)
    if not userId then return end

    local up, err = checkPresence(userId)
    if not up then return end

    if tostring(up.placeId) ~= tostring(daHoodPlaceId()) then
        return -- target not in Da Hood right now
    end

    local jobId, jerr = getTargetServer(userId)
    if jobId then
        pcall(function()
            TeleportService:TeleportToPlaceInstance(daHoodPlaceId(), jobId)
        end)
    end
end

local function cmdFollow(name)
    if not name or name == "" then
        notif("usage: .follow <username>")
        return
    end
    Follow.Target = name
    Follow.Enabled = true
    FollowRunning = true
    CachedUserId = nil
    notif("following " .. name .. " across servers")
end

local function cmdUnfollow()
    Follow.Enabled = false
    FollowRunning = false
    CachedUserId = nil
    notif("stopped following")
end

-- follow loop
task.spawn(function()
    while true do
        if Follow.Enabled and FollowRunning then
            pcall(hopToTarget)
        end
        task.wait(Follow.CheckInterval or 10)
    end
end)

-- auto-give when the target joins the same server as the bot
Players.PlayerAdded:Connect(function(plr)
    if Follow.Enabled and Follow.Target and plr.Name:lower() == Follow.Target:lower() then
        task.wait(2)
        State.Controller = plr
        if Follow.AutoGive and not State.StandActive then buildStand() end
        notif("giving stand to " .. plr.Name)
    end
end)

-- ============================================================
-- CODE REDEMPTION SYSTEM (Da Hood in-game cash codes)
-- ============================================================
local CodeRemote = nil

local function findCodeRemote()
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            local n = v.Name:lower()
            if n:find("code") or n:find("redeem") then
                return v
            end
        end
    end
    return nil
end

local function redeemDaHoodCode(code)
    CodeRemote = CodeRemote or findCodeRemote()
    if not CodeRemote then
        notif("no code remote found in ReplicatedStorage")
        return false
    end
    local ok, err = pcall(function()
        if CodeRemote:IsA("RemoteFunction") then
            CodeRemote:InvokeServer(tostring(code))
        else
            CodeRemote:FireServer(tostring(code))
        end
    end)
    return ok
end

local function cmdCodes()
    local cfg = Settings.Codes or {}
    local promos = cfg.PromoCodes or {}

    if #promos == 0 then
        notif("no codes in Settings.Codes.PromoCodes")
        return
    end

    CodeRemote = findCodeRemote()
    if not CodeRemote then
        notif("code remote not found — can't redeem")
        return
    end

    notif("code remote: " .. CodeRemote:GetFullName())

    task.spawn(function()
        for _, code in ipairs(promos) do
            local ok = redeemDaHoodCode(code)
            notif(code .. " | " .. (ok and "sent" or "error"))
            task.wait(0.5)
        end
        notif("code pass complete")
    end)
end

-- ============================================================
-- COMMAND DISPATCHER
-- ============================================================
local Dispatch = {
    fix           = function() cmdFix() end,
    reset         = function() cmdResetStand() end,
    summon        = function() cmdSummon() end,
    vanish        = function() cmdVanish() end,
    cpos          = function(a) cmdSetStandPosition(a) end,
    frame         = function(a) cmdFramePlayer(a[1]) end,
    asave         = function() cmdAutoSaveToggle() end,
    psave         = function(a) cmdAutoSavePlayer(a[1]) end,
    unpsave       = function(a) cmdUnAutoSavePlayer(a[1]) end,
    unpsaveall    = function() cmdUnAutoSaveAll() end,
    kill          = function(a) cmdKill(a[1]) end,
    lkill         = function(a) startLoop("lkill" .. (a[1] or ""), "loop kill", function() cmdKill(a[1]) end) end,
    knock         = function(a) cmdKnock(a[1]) end,
    lknock        = function(a) startLoop("lknock" .. (a[1] or ""), "loop knock", function() cmdKnock(a[1]) end) end,
    bring         = function(a) cmdBring(a[1]) end,
    drop          = function(a) cmdDrop(a[1]) end,
    gbring        = function(a) cmdGunBring(a[1]) end,
    lgknock       = function(a) startLoop("lgknock" .. (a[1] or ""), "loop gun knock", function() cmdGunKnock(a[1]) end) end,
    lgkill        = function(a) startLoop("lgkill" .. (a[1] or ""), "loop gun kill", function() cmdGunKill(a[1]) end) end,
    gknock        = function(a) cmdGunKnock(a[1]) end,
    gkill         = function(a) cmdGunKill(a[1]) end,
    bend          = function(a) cmdBend(a[1]) end,
    blow          = function(a) cmdBlow(a[1]) end,
    void          = function(a) cmdVoid(a[1]) end,
    gvoid         = function(a) cmdGunVoid(a[1]) end,
    sky           = function(a) cmdSky(a[1]) end,
    gsky          = function(a) cmdGunSky(a[1]) end,
    whitelist     = function(a) cmdWhitelist(a[1]) end,
    unwhitelist   = function(a) cmdUnwhitelist(a[1]) end,
    unwhitelistall= function() cmdUnwhitelistAll() end,
    tp            = function(a) cmdTeleport(a[1]) end,
    apos          = function() cmdChangeAutoSavePosition() end,
    ctp           = function() cmdChangeTeleportMethod() end,
    cattack       = function() cmdChangeAttackMode() end,
    cgattack      = function() cmdChangeAttackGun() end,
    cmask         = function(a) cmdChangeMask(a) end,
    view          = function(a) cmdView(a[1]) end,
    lfarm         = function() cmdFarm("lettuce", "lettuce") end,
    wfarm         = function() cmdFarm("weight", "weight") end,
    cfarm         = function() cmdFarm("cash", "cash") end,
    sfarm         = function() cmdFarm("stomp", "stomp") end,
    getback       = function() cmdAutoGetBack() end,
    aheal         = function() cmdAutoHeal() end,
    aarmor        = function() cmdAutoArmor() end,
    adrop         = function() cmdAutoDropCash() end,
    aura          = function() cmdKillAura() end,
    team          = function(a) cmdTeam(a[1]) end,
    unteamall     = function() cmdUnteamAll() end,
    amask         = function() cmdToggleMask() end,
    multig        = function(a) cmdMultiGun(a[1]) end,
    unmultig      = function() cmdUnMultiGun() end,
    mkill         = function(a) cmdMultiKillAdd(a[1]) end,
    skill         = function() cmdStartMultiKill() end,
    ckill         = function() cmdClearMultiKill() end,
    slgkill       = function(a) cmdLoopGunMulti(a[1]) end,
    give          = function(a) cmdGive(a[1]) end,
    take          = function() cmdTake() end,
    protect       = function(a) cmdProtect(a[1]) end,
    unprotect     = function(a) cmdUnprotect(a[1]) end,
    unprotectall  = function() cmdUnprotectAll() end,
    save          = function(a) cmdSave(a) end,
    unsave        = function(a) cmdUnsave(a) end,
    unsaveall     = function() cmdUnsaveAll() end,
    follow        = function(a) cmdFollow(a[1]) end,
    unfollow      = function() cmdUnfollow() end,
    codes         = function() cmdCodes() end,
}

local function execCommand(body)
    local parts = {}
    for token in body:gmatch("%S+") do
        table.insert(parts, token:lower())
    end
    local cmd = parts[1]
    if not cmd then return end
    local args = { select(2, unpack(parts)) }
    local fn = Dispatch[cmd]
    if fn then
        pcall(function() fn(args) end)
    else
        notif("unknown command: " .. tostring(cmd))
    end
end

local function runCommand(message)
    if message:sub(1, #Prefix) ~= Prefix then return end
    local body = message:sub(#Prefix + 1)
    execCommand(body)
end

-- route chat from the current controller only
Players.PlayerChatted:Connect(function(plr, message)
    if plr == State.Controller then
        runCommand(message)
    end
end)

-- if the controller leaves, return ownership to you
Players.PlayerRemoving:Connect(function(plr)
    if plr == State.Controller then
        State.Controller = LP
        notif(plr.Name .. " left — stand taken back")
    end
end)

-- ============================================================
-- DISCORD REMOTE CONTROL
-- ============================================================
local Discord = Settings.Discord or {}
local DiscordLastMsg = nil

local function discordFetch(path)
    return httpRequest({
        Url    = "https://discord.com/api/v10" .. path,
        Method = "GET",
        Headers = { ["Authorization"] = "Bot " .. (Discord.BotToken or "") },
    })
end

local function pollDiscord()
    if not Discord.Enabled
        or not Discord.BotToken or Discord.BotToken == ""
        or not Discord.ChannelId or Discord.ChannelId == "" then
        return
    end

    local res = discordFetch("/channels/" .. Discord.ChannelId .. "/messages?limit=5")
    if not res then return end

    local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not ok or type(data) ~= "table" or #data == 0 then return end

    -- first poll: sync to latest without replaying old commands
    if not DiscordLastMsg then
        DiscordLastMsg = data[1].id
        return
    end

    local toRun = {}
    local newId = DiscordLastMsg
    for i = #data, 1, -1 do  -- oldest -> newest
        local m = data[i]
        local mid = m and m.id
        if mid and tonumber(mid) > tonumber(DiscordLastMsg) then
            table.insert(toRun, m.content or "")
            newId = mid
        end
    end
    DiscordLastMsg = newId

    for _, content in ipairs(toRun) do
        execCommand(content)
    end
end

task.spawn(function()
    while true do
        pcall(pollDiscord)
        task.wait(Discord.PollInterval or 3)
    end
end)

-- ============================================================
-- FPSCAP
-- ============================================================
if Config.FPSCap and Config.FPSCap > 0 then
    -- soft cap by yielding the heartbeat budget is not possible directly;
    -- store setting for reference / used by executor-specific hooks
    Settings.Configs.FPSCap = Config.FPSCap
end

notif("Stand Bot loaded | prefix: " .. Prefix)
notif("executor: " .. Executor.Name .. " | http: " .. (Executor.HttpFn and "yes" or "no"))
