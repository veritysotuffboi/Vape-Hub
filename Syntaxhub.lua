local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Workspace  = game:GetService("Workspace")
local CoreGui    = game:GetService("CoreGui")
local Lighting   = game:GetService("Lighting")
local Tween      = game:GetService("TweenService")
local RS         = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Teams      = game:GetService("Teams")
local TweenSvc   = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

if getgenv then
    if getgenv().syntax then pcall(function() getgenv().syntax._unload() end) end
end
local Hub = {}; if getgenv then getgenv().syntax = Hub end

local F = {
    Aim = { On=false, Held=false, Part="Head", TeamCheck=true, WallCheck=false, Smooth=0.20, FOV=120, ShowFOV=true, Predict=0.0, Trigger=false, TrigDelay=60, Silent=false, Fire=false, HitChance=85, HeadshotChance=65 },
    ESP = { On=false, Box=true, Filled=false, Name=true, Dist=true, Health=true, Tracer=false, Skeleton=false, EnemiesOnly=false },
    Mov = { Speed=false, SpeedV=50, JumpOn=false, JumpV=80, Fly=false, FlyV=2.5, FlyNoclip=false, Noclip=false, InfJump=false, CarFly=false, CarFlySpeed=120, Spin=false, SpinV=5, NcGlitch=false },
    Wld = { Fullbright=false, NoFog=false, FOV=70, AntiAFK=false },
    UI  = { Boxes=true, RGB=false },
    Esc = { AutoEscape=false },
    Prot= { AntiArrest=false, AntiTase=true, EnableReset=true, AntiVoid=true },
    Feed= { Kill=true, Hostile=true },
    Auto= { Guns=false, GunList={}, Toilets=false, Keycard=true, Doors=false, TDoors=false, AJR=true, AutoRespawn=false, FastGuns=false, FireRate=0, OldSounds=true, OldSoundsMe=false },
    KA  = { On=false, Range=12, MaxTargets=10, Angle=360, RequireMouse=false },
    TB  = { On=false },
    AA  = { On=false, Range=8, HandCheck=true, InmatesEnabled=true, CriminalsEnabled=true },
    AT  = { On=false },
    DIS = { On=false },
    GM  = { On=false, FireRate=100, NoSpread=false, FullAuto=false },
    VWB = { On=false },
}
Hub.F = F

local aa_wl = {}
local attached = true
local conns = {}
local function bind(s, f) local c = s:Connect(f); conns[#conns+1] = c; return c end

local function cam()  return Workspace.CurrentCamera end
local function char() return LocalPlayer.Character end
local function root() local c=char(); return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso")) end
local function hum()  local c=char(); return c and c:FindFirstChildOfClass("Humanoid") end
local function alive(p) local c=p.Character; local h=c and c:FindFirstChildOfClass("Humanoid"); return h and h.Health>0, c, h end
local function key(k) return UIS:IsKeyDown(k) end
local function aimOrigin() return UIS:GetMouseLocation() end

local function Notify(text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title="syntax"; Text=text; Duration=dur or 3 })
    end)
end

local ENEMY_MODES = {"Enemy team","Cops (Guards)","Criminals","Everyone"}
local enemyMode = 1
local function isEnemy(p)
    if not p or p == LocalPlayer then return false end
    local m = ENEMY_MODES[enemyMode]; local tn = p.Team and p.Team.Name:lower() or ""
    if m == "Everyone" then return true
    elseif m == "Cops (Guards)" then return (tn:find("guard") or tn:find("police") or tn:find("cop")) ~= nil
    elseif m == "Criminals" then return (tn:find("crim") or tn:find("mafia")) ~= nil
    else return p.Team ~= LocalPlayer.Team end
end

local fakeFloor = nil
local fakeFloorUsers = 0

local function spawnFakeFloor()
    if fakeFloor and fakeFloor.Parent then return end
    local p = Instance.new("Part")
    p.Name="SyntaxFloor"; p.Size=Vector3.new(10,1,10); p.Anchored=true
    p.CanCollide=true; p.Transparency=1; p.CastShadow=false
    p.CanQuery=false; p.CanTouch=false; p.Parent=Workspace
    fakeFloor = p
end
local function destroyFakeFloor()
    if fakeFloor then pcall(function() fakeFloor:Destroy() end); fakeFloor=nil end
end
local function acquireFloor() fakeFloorUsers+=1; spawnFakeFloor() end
local function releaseFloor() fakeFloorUsers=math.max(0,fakeFloorUsers-1); if fakeFloorUsers==0 then destroyFakeFloor() end end
local function tickFakeFloor() local r=root(); if fakeFloor and fakeFloor.Parent and r then fakeFloor.CFrame=CFrame.new(r.Position.X,r.Position.Y-3,r.Position.Z) end end

local _noclipTemp = false
local _noclipTempConns = {}

local function tempNoclipOn()
    if _noclipTemp then return end; _noclipTemp=true
    local c=char(); if not c then return end
    for _,v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then
            pcall(function() v.CanCollide=false end)
            local conn=v:GetPropertyChangedSignal("CanCollide"):Connect(function()
                if _noclipTemp and v.CanCollide then v.CanCollide=false end end)
            _noclipTempConns[#_noclipTempConns+1]=conn
        end
    end
end
local function tempNoclipOff()
    if not _noclipTemp then return end; _noclipTemp=false
    for _,c in ipairs(_noclipTempConns) do pcall(function() c:Disconnect() end) end
    _noclipTempConns={}
    if not F.Mov.Noclip then
        local c=char()
        if c then for _,v in ipairs(c:GetDescendants()) do
            if v:IsA("BasePart") and v.Name~="HumanoidRootPart" then pcall(function() v.CanCollide=true end) end
        end end
    end
end

local function tweenTP(cf, dur)
    local r=root(); if not (r and cf) then return end; dur=dur or 0.22
    tempNoclipOn(); acquireFloor()
    local startCF=r.CFrame; local t0=os.clock()
    while true do
        local a=(os.clock()-t0)/dur; if a>=1 then break end
        a=1-(1-a)*(1-a)
        pcall(function() r.CFrame=startCF:Lerp(cf,a); r.AssemblyLinearVelocity=Vector3.zero end)
        RunService.Heartbeat:Wait()
    end
    pcall(function() r.CFrame=cf; r.AssemblyLinearVelocity=Vector3.zero end)
    RunService.Heartbeat:Wait(); releaseFloor(); tempNoclipOff()
end
local function tpMove(cf) if cf then task.spawn(tweenTP,cf,0.22) end end
local function tpInstant(cf) local r=root(); if r and cf then r.CFrame=cf end end

local noclipConns = {}
local CharacterCollision = RS.Scripts and RS.Scripts:FindFirstChild("CharacterCollision")

local function clearNoclip()
    for _,c in ipairs(noclipConns) do pcall(function() c:Disconnect() end) end; noclipConns={}
end
local function applyNoclip()
    clearNoclip(); local c=char(); if not c then return end
    if CharacterCollision then pcall(function() CharacterCollision.Enabled=false end) end
    for _,v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then
            v.CanCollide=false
            noclipConns[#noclipConns+1]=v:GetPropertyChangedSignal("CanCollide"):Connect(function()
                if F.Mov.Noclip and v.CanCollide then v.CanCollide=false end end)
        end
    end
end
local function stopNoclip()
    clearNoclip()
    if CharacterCollision then pcall(function() CharacterCollision.Enabled=true end) end
    local c=char()
    if c then for _,v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") and v.Name~="HumanoidRootPart" then pcall(function() v.CanCollide=true end) end
    end end
end

local function applySpin()
    local r=root(); if not r then return end
    for _,v in ipairs(r:GetChildren()) do if v.Name=="syntax_spin" then v:Destroy() end end
    if not F.Mov.Spin then return end
    local bav=Instance.new("BodyAngularVelocity")
    bav.Name="syntax_spin"; bav.MaxTorque=Vector3.new(0,math.huge,0)
    bav.AngularVelocity=Vector3.new(0,F.Mov.SpinV*10,0); bav.Parent=r
end
local function stopSpin()
    local r=root(); if not r then return end
    for _,v in ipairs(r:GetChildren()) do if v.Name=="syntax_spin" then v:Destroy() end end
end

local snacks = {"Chips","Chocolate","Soda"}
local _ncLastMove, _ncLastJump, _ncCooldown = 0, 0, false
local function isHoldingSnack()
    local c=char(); if not c then return false end
    local t=c:FindFirstChildOfClass("Tool")
    return t and table.find(snacks,t.Name) ~= nil
end

local carFlyConn = nil
local carFlyObjects = {}
local function GetSeatVehicle()
    local c=char(); if not c then return nil end
    local h=c:FindFirstChildOfClass("Humanoid"); if not h then return nil end
    local seat=h.SeatPart; if not seat then return nil end
    return seat:FindFirstAncestorWhichIsA("Model")
end
local function stopCarFly()
    if carFlyConn then pcall(function() carFlyConn:Disconnect() end); carFlyConn=nil end
    for _,obj in ipairs(carFlyObjects) do pcall(function() obj:Destroy() end) end; carFlyObjects={}
end
local function setupCarFly()
    stopCarFly(); if not F.Mov.CarFly then return end
    local vehicle=GetSeatVehicle(); if not vehicle then return end
    local pp=vehicle.PrimaryPart
    if not pp then
        for _,v in ipairs(vehicle:GetDescendants()) do
            if v:IsA("BasePart") and (v.Name=="Body" or v.Name=="Chassis" or v.Name=="DriveSeat" or v:IsA("VehicleSeat")) then pp=v; break end
        end
    end
    if not pp then return end
    for _,v in ipairs(vehicle:GetDescendants()) do if v:IsA("BasePart") then v.Anchored=false end end
    local bv=Instance.new("BodyVelocity"); bv.MaxForce=Vector3.new(1e9,1e9,1e9); bv.Velocity=Vector3.zero; bv.Parent=pp; table.insert(carFlyObjects,bv)
    local bg=Instance.new("BodyGyro"); bg.MaxTorque=Vector3.new(1e9,1e9,1e9); bg.D=500; bg.P=1e5; bg.CFrame=pp.CFrame; bg.Parent=pp; table.insert(carFlyObjects,bg)
    for _,v in ipairs(vehicle:GetDescendants()) do
        if v:IsA("BasePart") and v~=pp then
            local w=Instance.new("WeldConstraint"); w.Part0=pp; w.Part1=v; w.Parent=pp; table.insert(carFlyObjects,w)
        end
    end
    carFlyConn=RunService.RenderStepped:Connect(function()
        local veh=GetSeatVehicle()
        if not F.Mov.CarFly or not veh or veh~=vehicle then stopCarFly(); return end
        local md=Vector3.zero
        if key(Enum.KeyCode.W) then md+=cam().CFrame.LookVector end
        if key(Enum.KeyCode.S) then md-=cam().CFrame.LookVector end
        if key(Enum.KeyCode.A) then md-=cam().CFrame.RightVector end
        if key(Enum.KeyCode.D) then md+=cam().CFrame.RightVector end
        if key(Enum.KeyCode.Space) then md+=Vector3.new(0,1,0) end
        if key(Enum.KeyCode.LeftControl) then md-=Vector3.new(0,1,0) end
        if md.Magnitude>0 then md=md.Unit end
        bv.Velocity=md*F.Mov.CarFlySpeed
        local _,yaw,_=cam().CFrame:ToEulerAnglesYXZ()
        bg.CFrame=CFrame.new(pp.Position)*CFrame.Angles(0,yaw,0)
    end)
end

local fbState
local function fullbright(on)
    if on then
        fbState=fbState or {b=Lighting.Brightness,ct=Lighting.ClockTime,fe=Lighting.FogEnd,am=Lighting.Ambient,oa=Lighting.OutdoorAmbient,gs=Lighting.GlobalShadows}
        Lighting.Brightness=2; Lighting.ClockTime=14; Lighting.FogEnd=1e9
        Lighting.Ambient=Color3.fromRGB(178,178,178); Lighting.OutdoorAmbient=Color3.fromRGB(178,178,178); Lighting.GlobalShadows=false
    elseif fbState then
        Lighting.Brightness=fbState.b; Lighting.ClockTime=fbState.ct; Lighting.FogEnd=fbState.fe
        Lighting.Ambient=fbState.am; Lighting.OutdoorAmbient=fbState.oa; Lighting.GlobalShadows=fbState.gs
    end
end

local autoEscapeTriggered = false
local healthConn = nil
local function TeleportToTree()
    local TreeFolder=Workspace:FindFirstChild("TreeFolder"); if not TreeFolder then return end
    local trees={}; for _,t in ipairs(TreeFolder:GetChildren()) do if t.Name:find("tree") then table.insert(trees,t) end end
    if #trees==0 then return end
    local r=root(); if not r then return end
    local target=trees[math.random(1,#trees)]
    r.CFrame=CFrame.new(target:GetPivot().Position+Vector3.new(0,8,0))
end
local function setupAutoEscape()
    if healthConn then pcall(function() healthConn:Disconnect() end); healthConn=nil end
    autoEscapeTriggered=false; if not F.Esc.AutoEscape then return end
    local function bindHealth(ch)
        local h=ch:FindFirstChildOfClass("Humanoid"); if not h then return end
        autoEscapeTriggered=false
        healthConn=h.HealthChanged:Connect(function(hp)
            if not F.Esc.AutoEscape or autoEscapeTriggered then return end
            if hp/h.MaxHealth<=0.3 then autoEscapeTriggered=true; TeleportToTree(); task.delay(3,function() autoEscapeTriggered=false end) end
        end)
    end
    if char() then bindHealth(char()) end
    LocalPlayer.CharacterAdded:Connect(function(ch) task.wait(0.3); autoEscapeTriggered=false; if F.Esc.AutoEscape then bindHealth(ch) end end)
end

local Remotes       = RS:FindFirstChild("Remotes")
local ShootRemote   = nil
local GiverRemote   = Remotes and Remotes:FindFirstChild("GiverPressed")
local ReloadRemote  = nil
local InteractItem  = Remotes and Remotes:FindFirstChild("InteractWithItem")
local TeamEvent     = Remotes and Remotes:FindFirstChild("RequestTeamChange")
local ArrestRemote  = Remotes and Remotes:FindFirstChild("ArrestPlayer")
local Killfeed      = RS:FindFirstChild("Killfeed")
local GunRemotes    = nil
local PlayerTased   = nil

pcall(function()
    GunRemotes = RS:FindFirstChild("GunRemotes") or RS:WaitForChild("GunRemotes",5)
    ShootRemote = GunRemotes and (GunRemotes:FindFirstChild("ShootEvent") or GunRemotes:WaitForChild("ShootEvent",5))
    ReloadRemote = ShootRemote and ShootRemote.Parent:FindFirstChild("FuncReload")
    PlayerTased = GunRemotes and GunRemotes:FindFirstChild("PlayerTased")
end)

local meleeEvent
pcall(function() meleeEvent=RS:FindFirstChild("meleeEvent") or RS:WaitForChild("meleeEvent",3) end)

local rand = Random.new()

local _silentHook = false
local _gmOldData, _gmOld = {}, nil
local _gmOldEquip = nil

do
    local hookmeta=hookmetamethod; local getnc=getnamecallmethod; local ischeck=checkcaller
    local wrapcc=newcclosure or function(f) return f end
    if hookmeta and getnc then
        local oldNC
        oldNC=hookmeta(game,"__namecall",wrapcc(function(self,...)
            local method=getnc()

            if method=="GetAttributes" then
                local result=oldNC(self,...)
                if F.Auto.FastGuns then result.AutoFire=true; result.FireRate=F.Auto.FireRate end
                if F.GM.On and _gmOld then
                    if F.GM.NoSpread then result.SpreadRadius=0 end
                    if F.GM.FullAuto then result.AutoFire=true end
                    if result.FireRate then result.FireRate=result.FireRate*(F.GM.FireRate/100) end
                end
                return result
            end

            if F.Aim.Silent and attached and self==ShootRemote
               and (not ischeck or not ischeck()) and method=="FireServer" then
                local shots=...
                if type(shots)=="table" then
                    if rand:NextNumber(0,100) <= F.Aim.HitChance then
                        local targetPart = rand:NextNumber(0,100) <= F.Aim.HeadshotChance and "Head" or "HumanoidRootPart"
                        local ok,t=pcall(function() return Aim.getTarget(F.Aim.FOV,F.Aim.WallCheck,targetPart) end)
                        if ok and t then
                            for _,e in ipairs(shots) do
                                if type(e)=="table" then e[2]=t.Position; e[3]=t end
                            end
                        end
                    end
                end
            end
            return oldNC(self,...)
        end))
        _silentHook=true
    end
end
Hub._silentHook=_silentHook

local Aim = {}
do
    local function los(part)
        local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances={char()}
        local o=cam().CFrame.Position; local r=Workspace:Raycast(o,part.Position-o,rp)
        return (not r) or r.Instance:IsDescendantOf(part.Parent)
    end
    function Aim.getTarget(maxFov, needLos, partName)
        local pn = partName or F.Aim.Part
        local best,bd=nil,maxFov or F.Aim.FOV; local center=aimOrigin()
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and isEnemy(p) then
                local ok,c=alive(p)
                local part=ok and (c:FindFirstChild(pn) or c:FindFirstChild("HumanoidRootPart"))
                if part then
                    local sp,on=cam():WorldToViewportPoint(part.Position)
                    if on then local d=(Vector2.new(sp.X,sp.Y)-center).Magnitude
                        if d<bd and ((not needLos and not F.Aim.WallCheck) or los(part)) then bd,best=d,part end
                    end
                end
            end
        end
        return best
    end
end

local function fireClick()
    if mouse1press and mouse1release then pcall(function() mouse1press(); task.wait(0.02); mouse1release() end)
    elseif mouse1click then pcall(mouse1click) end
end

local function heldGun()
    local c=char(); if c then for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") then return t,true end end end
    local bp=LocalPlayer:FindFirstChild("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then return t,false end end end
    return nil
end
local function reloadGun(tool)
    if not (tool and ReloadRemote) then return end
    pcall(function()
        local sess=tick(); tool:SetAttribute("Local_ReloadSession",sess)
        task.spawn(function() ReloadRemote:InvokeServer() end)
        task.wait(tool:GetAttribute("ReloadTime") or 2)
        tool:SetAttribute("Local_CurrentAmmo",tool:GetAttribute("MaxAmmo") or 30)
        tool:SetAttribute("Local_ReloadSession",0)
    end)
end
local function findGiver()
    local team=(LocalPlayer.Team and LocalPlayer.Team.Name or ""):lower()
    local want=team:find("guard") and "Remington 870" or "AK-47"; local fallback
    for _,d in ipairs(Workspace:GetDescendants()) do
        local tn=d:GetAttribute("ToolName")
        if tn then
            local part=d:IsA("BasePart") and d or d:FindFirstChildWhichIsA("BasePart",true)
            if part then
                if tn==want then return part end
                local low=tostring(tn):lower()
                if not fallback and (low:find("ak") or low:find("rifle") or low:find("gun") or low:find("pistol") or low:find("smg") or low:find("remington")) then fallback=part end
            end
        end
    end
    return fallback
end
local function armUp()
    local g,equipped=heldGun()
    if g then if not equipped then pcall(function() hum():EquipTool(g) end) end; return true end
    local giver=findGiver(); local r=root()
    if giver and r and GiverRemote then
        local save=r.CFrame
        pcall(function() r.CFrame=CFrame.new(giver.Position+Vector3.new(0,2.5,0)) end)
        task.wait(0.3)
        pcall(function() GiverRemote:FireServer(giver) end)
        pcall(function() if giver.Parent then GiverRemote:FireServer(giver.Parent) end end)
        task.wait(0.3); pcall(function() r.CFrame=save end); task.wait(0.2)
    end
    g,equipped=heldGun()
    if g then if not equipped then pcall(function() hum():EquipTool(g) end) end; return true end
    return false
end
local raging=false
Hub._raging=function() return raging end
local function doRage(target)
    if raging or not (target and target.Parent) or not ShootRemote then return end
    raging=true
    task.spawn(function()
        pcall(function()
            local r=root(); if not r then raging=false; return end
            local home=r.CFrame
            if not armUp() then raging=false; return end
            task.wait(0.15)
            local tool=char() and char():FindFirstChildOfClass("Tool"); if not tool then raging=false; return end
            local fireRate=tool:GetAttribute("FireRate") or 0.12
            local interval=math.max(fireRate,0.09)+0.02
            local maxAmmo=tool:GetAttribute("MaxAmmo") or 20
            local ammo=tool:GetAttribute("Local_CurrentAmmo") or maxAmmo
            if ammo<12 then reloadGun(tool) end
            local tc=target.Character
            local troot=tc and (tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Torso"))
            local thum=tc and tc:FindFirstChildOfClass("Humanoid")
            if not (troot and thum and thum.Health>0) then raging=false; return end
            tweenTP(troot.CFrame*CFrame.new(0,0,3.2),0.2); task.wait(0.08)
            local fired=0
            while thum and thum.Parent and thum.Health>0 and fired<28 do
                local thead=tc and tc:FindFirstChild("Head"); if not thead then break end
                local mh=char() and char():FindFirstChild("Head")
                local o=(mh and mh.Position) or thead.Position
                pcall(function() ShootRemote:FireServer({{o,thead.Position,thead}}) end)
                fired+=1
                local left=(tool:GetAttribute("Local_CurrentAmmo") or maxAmmo)-1
                pcall(function() tool:SetAttribute("Local_CurrentAmmo",left) end)
                if left<=1 then reloadGun(tool) end
                task.wait(interval)
                local ntr=tc and (tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Torso"))
                local rr=root()
                if ntr and rr and (rr.Position-ntr.Position).Magnitude>9 then tweenTP(ntr.CFrame*CFrame.new(0,0,3.2),0.12) end
            end
            tweenTP(home,0.2)
        end)
        raging=false
    end)
end
Hub._rage=doRage

local gunAliases = {
    ["ak-47"]="AK-47",["ak"]="AK-47",["ak47"]="AK-47",
    ["remington"]="Remington 870",["rem"]="Remington 870",["shotgun"]="Remington 870",
    ["m4"]="M4A1",["m4a1"]="M4A1",["mp5"]="MP5",["fal"]="FAL",["m700"]="M700"
}

local AlreadyFound={}
local function FindGunSpawner(GunName)
    if AlreadyFound[GunName] then return AlreadyFound[GunName],true end
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v.Name=="TouchGiver" then
            local ActualGiver=v:FindFirstChild("TouchGiver") or v
            if v:GetAttribute("ToolName")==GunName then AlreadyFound[GunName]=ActualGiver; return ActualGiver,false end
            if v.Parent and v.Parent:GetAttribute("ToolName")==GunName then AlreadyFound[GunName]=ActualGiver; return ActualGiver,false end
        end
    end
    return nil,nil
end
local function GetTool(name)
    return (LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild(name))
        or (char() and char():FindFirstChild(name))
end
local function GetGun(GunName)
    local Giver,Found=FindGunSpawner(GunName); if not Giver then Notify("Can't find giver for "..GunName); return end
    if not Found then
        local Clone=Giver:Clone(); Clone.Parent=Giver.Parent
        Giver.Parent=Workspace.Folder; Giver.CanCollide=false; Giver.Transparency=1
    end
    local r=root(); if not r then return end
    r.CFrame=Giver.CFrame*CFrame.new(math.random(-2,2),0,0)
    local timeout=tick()+5
    repeat task.wait() until GetTool(GunName) or tick()>timeout
end

local allGuns={"AK-47","Remington 870","MP5"}

local _autoGunRunning=false
local _autoGunLst=os.clock()
local AUTOGUN_DELAY=10

local _kcRunning=false
local function tryGiveKeycard()
    local bp=LocalPlayer:FindFirstChild("Backpack"); if not bp then return end
    if bp:FindFirstChild("Key card") or (LocalPlayer.Team and LocalPlayer.Team.Name=="Guards") then return end
    local toolsFolder=RS:FindFirstChild("Tools")
    local source=(toolsFolder and toolsFolder:FindFirstChild("Key card",true))
    if not source then
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer then local bk=p:FindFirstChild("Backpack"); if bk then local t=bk:FindFirstChild("Key card"); if t then source=t; break end end end
        end
    end
    if source then pcall(function() source:Clone().Parent=bp end) end
end
local function startKeycard()
    if _kcRunning then return end; _kcRunning=true
    task.spawn(function()
        while _kcRunning do pcall(tryGiveKeycard); task.wait(0.3) end
    end)
end

local normalWS=25
local normalJP=50
local function fixTools()
    local c=char(); if not c then return end
    local h=c:FindFirstChild("Humanoid"); if not h then h:UnequipTools() end
    local bp=LocalPlayer:FindFirstChild("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then t.Enabled=true end end end
end
local function restoreSpeed(ws,jp)
    task.wait(3); local h=hum(); if h then h.WalkSpeed=ws; h.JumpPower=jp end
end

local fugging=false
local function SwitchToCriminalAndReturn(ocf)
    fugging=true
    task.spawn(function()
        pcall(function()
            local crimPad=Workspace["Criminals Spawn"] and Workspace["Criminals Spawn"]:FindFirstChild("SpawnLocation")
            local r=root(); if not r then return end
            r.CFrame=crimPad and crimPad.CFrame or CFrame.new(-864,94,2085)
            Notify("Switching to Criminal...")
            local timeout=tick()+10
            repeat task.wait() until (LocalPlayer.Team and LocalPlayer.Team.Name=="Criminals") or tick()>timeout
            Notify("Criminal!"); r.CFrame=ocf; Notify("Returned.")
        end)
        fugging=false
    end)
end

local Doors=Workspace:FindFirstChild("Doors")
local CellDoors=Workspace:FindFirstChild("CellDoors")
local function NoDoors()
    if Doors then for _,v in ipairs(Doors:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=false end end end
    if CellDoors then for _,v in ipairs(CellDoors:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=false end end end
end
local function AddDoors()
    if Doors then for _,v in ipairs(Doors:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=true end end end
    if CellDoors then for _,v in ipairs(CellDoors:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=true end end end
end
local function TransparentDoors(on)
    local tr=on and 0.6 or 0
    if Doors then for _,v in ipairs(Doors:GetDescendants()) do if v:IsA("BasePart") then v.Transparency=tr end end end
    if CellDoors then for _,v in ipairs(CellDoors:GetDescendants()) do if v:IsA("BasePart") then v.Transparency=tr end end end
end
local function DestroyDoors()
    if Doors then for _,v in ipairs(Doors:GetDescendants()) do if v:IsA("BasePart") then v:Destroy() end end end
    if CellDoors then for _,v in ipairs(CellDoors:GetDescendants()) do if v:IsA("BasePart") then v:Destroy() end end end
end

local function UkFence()
    for _,fence in ipairs(Workspace.Prison_Fences:GetDescendants()) do
        local dp=fence:FindFirstChild("damagePart")
        if dp then for _,child in ipairs(dp:GetChildren()) do if child:IsA("TouchTransmitter") then child:Destroy() end end end
    end
end
local function DestroyFences()
    pcall(function()
        for _,v in ipairs(Workspace.Prison_Fences:GetChildren()) do if v.Name=="fence" then v:Destroy() end end
    end)
end
local function DestroyGates()
    pcall(function()
        Workspace.Prison_Fences.Prison_Gate:Destroy()
        Workspace.Prison_Fences.gate:Destroy()
    end)
end

local function BreakAllToilets()
    if not meleeEvent then return end
    for _,toilet in ipairs(Workspace:GetDescendants()) do
        if toilet.Name=="Toilet" and toilet:IsA("Model") then
            for i=1,15 do meleeEvent:FireServer(toilet,1) end
        end
    end
end
local _hammerHeld=false
local function hammerCheck()
    local c=char(); if not c then return end
    local hasHammer=c:FindFirstChild("Hammer")~=nil
    if hasHammer and not _hammerHeld then BreakAllToilets() end
    _hammerHeld=hasHammer
end

local function ajr()
    local c=char(); if not c then return end
    local aj=c:FindFirstChild("AntiJump")
    if aj and aj:IsA("LocalScript") then pcall(function() aj:Destroy() end) end
end

local function hideTrees(hide)
    local trees=Workspace:FindFirstChild("Trees"); if not trees then return end
    local kids=trees:GetChildren(); local preserve=kids[39]
    for i=#kids,1,-1 do
        local c=kids[i]
        if c~=preserve then
            for _,d in ipairs(c:GetDescendants()) do
                if d:IsA("BasePart") then
                    d.Transparency=hide and 1 or 0
                    d.CanCollide=not hide; d.CanQuery=not hide; d.CanTouch=not hide
                end
            end
        end
    end
end

local function killSelf()
    local h=hum(); if h then pcall(function() h.Health=0 end) end
end

local _antiTazeOld = nil
local _antiTazeConn = nil
local function setupAntiTaze()
    if not F.AT.On then
        if _antiTazeOld and _antiTazeConn and _antiTazeConn.Function then
            pcall(function() hookfunction(_antiTazeConn.Function, _antiTazeOld) end)
        end
        _antiTazeOld=nil; _antiTazeConn=nil
        return
    end
    if not PlayerTased then return end
    task.spawn(function()
        local conn
        local timeout=tick()+10
        repeat
            local ok,c=pcall(function() return getconnections(PlayerTased.OnClientEvent)[1] end)
            if ok and c and c.Function then conn=c end
            if not conn then task.wait(0.1) end
        until conn or tick()>timeout or not F.AT.On
        if not conn or not F.AT.On then return end
        _antiTazeConn=conn
        _antiTazeOld=hookfunction(conn.Function, function()
            local c=char()
            LocalPlayer:SetAttribute("BackpackEnabled",false)
            local h=hum()
            if h then h:UnequipTools() end
            task.wait(3.5)
            if LocalPlayer.Character==c then
                LocalPlayer:SetAttribute("BackpackEnabled",true)
            end
        end)
    end)
end

local _disablerConn = nil
local function setupDisabler(ch)
    if not F.DIS.On then return end
    if not ch then ch=char() end
    if not ch then return end
    local head=ch:FindFirstChild("Head")
    if not head then return end
    task.defer(function()
        local ok,conlist=pcall(function() return getconnections(head:GetPropertyChangedSignal("CanCollide")) end)
        if ok and conlist then
            for _,c in ipairs(conlist) do
                pcall(function() c:Disable() end)
            end
        end
    end)
end
local function stopDisabler(ch)
    if not ch then ch=char() end
    if not ch then return end
    local head=ch:FindFirstChild("Head")
    if not head then return end
    local ok,conlist=pcall(function() return getconnections(head:GetPropertyChangedSignal("CanCollide")) end)
    if ok and conlist then
        for _,c in ipairs(conlist) do
            pcall(function() c:Enable() end)
        end
    end
end

local _arrestCooldown = 0
local _arrestRunning = false
local function startAutoArrest()
    if _arrestRunning then return end
    _arrestRunning=true
    task.spawn(function()
        while _arrestRunning and F.AA.On do
            pcall(function()
                if _arrestCooldown < os.clock() then
                    local check=true
                    if F.AA.HandCheck then
                        local c=char()
                        local tool=c and c:FindFirstChildWhichIsA("Tool")
                        check=tool and tool.Name=="Handcuffs"
                    end
                    if check and ArrestRemote then
                        local r=root()
                        if r then
                            for _,p in ipairs(Players:GetPlayers()) do
                                if p~=LocalPlayer then
                                    local ok,c,h=alive(p)
                                    if ok and c then
                                        local pr=c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso")
                                        if pr and (pr.Position-r.Position).Magnitude<=F.AA.Range then
                                            local tn=p.Team and p.Team.Name or ""
                                            local isInmate=tn:lower():find("inmate")~=nil
                                            local isCrim=tn:lower():find("crim")~=nil or tn:lower():find("mafia")~=nil
                                            if not (isInmate and not F.AA.InmatesEnabled) and not (isCrim and not F.AA.CriminalsEnabled) then
                                                if not c:GetAttribute("Arrested") then
                                                    local res=pcall(function()
                                                        local r2=ArrestRemote:InvokeServer(p,1)
                                                        if r2 then
                                                            _arrestCooldown=os.clock()+7
                                                            Notify("Arrested "..p.Name,3)
                                                        end
                                                    end)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
            task.wait(0.05)
        end
        _arrestRunning=false
    end)
end
local function stopAutoArrest()
    _arrestRunning=false
end

local _tbRayParams = RaycastParams.new()
_tbRayParams.FilterType = Enum.RaycastFilterType.Exclude
local _tbCheckParams = RaycastParams.new()
_tbCheckParams.FilterType = Enum.RaycastFilterType.Exclude
local _tbRunning = false

local function getTriggerTarget()
    local c=char(); if not c then return end
    local head=c:FindFirstChild("Head"); if not head then return end
    local r=root(); if not r then return end
    local h=hum(); if not (h and h.Health>0) then return end

    local excl={c}
    if F.VWB.On then
        local cc=Workspace:FindFirstChild("CarContainer")
        if cc then excl[#excl+1]=cc end
    end
    _tbRayParams.FilterDescendantsInstances=excl
    _tbCheckParams.FilterDescendantsInstances=excl

    local posX,posY
    if UIS.MouseBehavior==Enum.MouseBehavior.LockCenter then
        posX=cam().ViewportSize.X/2; posY=cam().ViewportSize.Y/2
    else
        local loc=UIS:GetMouseLocation(); posX=loc.X; posY=loc.Y
    end

    local rayObj=cam():ViewportPointToRay(posX,posY)
    local ray=Workspace:Raycast(rayObj.Origin, rayObj.Direction*1500, _tbRayParams)
    if not ray then return end

    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and isEnemy(p) then
            local ok,pc,ph=alive(p)
            if ok and pc then
                if ray.Instance:IsDescendantOf(pc) then
                    local origin=head.Position
                    local hitCheck=Workspace:Raycast(origin, (ray.Position-origin), _tbCheckParams)
                    if hitCheck and hitCheck.Instance:IsDescendantOf(pc) then
                        return p
                    end
                end
            end
        end
    end
end

local function startTriggerBot()
    if _tbRunning then return end
    _tbRunning=true
    task.spawn(function()
        while _tbRunning and F.TB.On do
            pcall(function()
                local t=getTriggerTarget()
                if t and ShootRemote then
                    local c=char()
                    if c then
                        local tool=c:FindFirstChildWhichIsA("Tool")
                        if tool and tool:GetAttribute("FireRate") then
                            local ammo=tool:GetAttribute("Local_CurrentAmmo") or 1
                            if ammo>0 and not tool:GetAttribute("Local_IsShooting") then
                                local head=c:FindFirstChild("Head")
                                local tc=t.Character
                                local thead=tc and tc:FindFirstChild("Head")
                                if head and thead then
                                    pcall(function()
                                        ShootRemote:FireServer({{head.Position,thead.Position,thead}})
                                    end)
                                end
                            end
                        end
                    end
                end
            end)
            task.wait()
        end
        _tbRunning=false
    end)
end
local function stopTriggerBot()
    _tbRunning=false
end

local _kaRunning = false
local function startKillaura()
    if _kaRunning then return end
    _kaRunning=true
    task.spawn(function()
        while _kaRunning and F.KA.On do
            pcall(function()
                if F.KA.RequireMouse and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                    task.wait(0.05); return
                end
                local r=root(); if not r then return end
                local selfPos=r.Position
                local localFacing=(r.CFrame.LookVector*Vector3.new(1,0,1))
                local halfAngle=math.rad(F.KA.Angle)/2
                local count=0
                for _,p in ipairs(Players:GetPlayers()) do
                    if count>=F.KA.MaxTargets then break end
                    if p~=LocalPlayer and isEnemy(p) then
                        local ok,c=alive(p)
                        if ok and c then
                            local pr=c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso")
                            if pr then
                                local dist=(pr.Position-selfPos).Magnitude
                                if dist<=F.KA.Range then
                                    local delta=(pr.Position-selfPos)*Vector3.new(1,0,1)
                                    local angle=math.acos(math.clamp(localFacing:Dot(delta.Unit),-1,1))
                                    if angle<=halfAngle then
                                        if meleeEvent then
                                            pcall(function() meleeEvent:FireServer(p,1,1) end)
                                        end
                                        count+=1
                                    end
                                end
                            end
                        end
                    end
                end
            end)
            task.wait(0.05)
        end
        _kaRunning=false
    end)
end
local function stopKillaura()
    _kaRunning=false
end

if Killfeed then
    bind(Killfeed.ChildAdded,function(child)
        if F.Feed.Kill then Notify("☠ "..child.Name,2) end
    end)
end

local _htLastState={}
local function monitorHT(p)
    local function track(c)
        _htLastState[p]={Trespassing=false,Hostile=false}
        while c.Parent do
            task.wait(0.3)
            local tres=c:GetAttribute("Trespassing"); local hos=c:GetAttribute("Hostile")
            if p.Team and p.Team.Name:lower():find("inmate") then
                if tres and not _htLastState[p].Trespassing and F.Feed.Hostile then Notify(p.Name.." is TRESPASSING!") end
                if hos and not _htLastState[p].Hostile and F.Feed.Hostile then Notify(p.Name.." is HOSTILE!") end
            end
            _htLastState[p].Trespassing=tres; _htLastState[p].Hostile=hos
        end
    end
    p.CharacterAdded:Connect(track)
    if p.Character then task.spawn(track,p.Character) end
end
for _,p in ipairs(Players:GetPlayers()) do monitorHT(p) end
bind(Players.PlayerAdded,monitorHT)

local gunSounds={
    ["M4A1"]={ReloadSound="rbxassetid://142491708",ShootSound="rbxassetid://150544849"},
    ["AK-47"]={ReloadSound="rbxassetid://142491708",ShootSound="rbxassetid://153230498"},
    ["M9"]={ReloadSound="rbxassetid://138084889",ShootSound="rbxassetid://134436500"},
    ["Remington 870"]={ReloadSound="rbxassetid://145081845",ShootSound="rbxassetid://138083993"},
    ["M700"]={ReloadSound="rbxassetid://97852355",ShootSound="rbxassetid://406722373"},
    ["MP5"]={ReloadSound="rbxassetid://142491708",ShootSound="rbxassetid://10209859"},
    ["FAL"]={ReloadSound="rbxassetid://142491708"},
}
local function applySounds(tool)
    if not F.Auto.OldSounds then return end
    if F.Auto.OldSoundsMe and tool.Parent~=char() then return end
    local sounds=gunSounds[tool.Name]; if not sounds then return end
    for soundName,id in pairs(sounds) do
        for _,obj in ipairs(tool:GetDescendants()) do
            if obj:IsA("Sound") and obj.Name==soundName then obj.SoundId=id end
        end
    end
end
local function hookTool(tool)
    if not gunSounds[tool.Name] then return end
    applySounds(tool)
    tool.DescendantAdded:Connect(function(obj)
        if obj:IsA("Sound") and F.Auto.OldSounds then
            local id=gunSounds[tool.Name] and gunSounds[tool.Name][obj.Name]
            if id then obj.SoundId=id end
        end
    end)
end
local function hookCharacter(c)
    c.ChildAdded:Connect(function(child) if child:IsA("Tool") then hookTool(child) end end)
    for _,child in ipairs(c:GetChildren()) do if child:IsA("Tool") then hookTool(child) end end
end
for _,p in ipairs(Players:GetPlayers()) do if p.Character then hookCharacter(p.Character) end; p.CharacterAdded:Connect(hookCharacter) end
bind(Players.PlayerAdded,function(p) p.CharacterAdded:Connect(hookCharacter) end)

local lastDeathCF=nil

bind(LocalPlayer.CharacterAdded,function(newChar)
    task.wait(0.5)
    if F.Auto.AJR then ajr() end
    if F.Mov.Noclip then applyNoclip() end
    if F.Esc.AutoEscape then setupAutoEscape() end
    if F.Auto.Keycard then _kcRunning=false; task.wait(0.2); startKeycard() end
    if F.Auto.Guns then _autoGunRunning=false; _autoGunLst=os.clock() end
    if F.DIS.On then setupDisabler(newChar) end
    if F.AT.On then setupAntiTaze() end

    local charHum=newChar:WaitForChild("Humanoid")
    local animator=charHum:WaitForChild("Animator")

    animator.AnimationPlayed:Connect(function(track)
        if F.Prot.AntiArrest and track.Animation.AnimationId=="rbxassetid://287112271" then
            local r=root(); local wasCrim=LocalPlayer.TeamColor and LocalPlayer.TeamColor.Name=="Really red"
            local cpos=r and r.CFrame
            charHum.Health=0
            LocalPlayer.CharacterAdded:Wait()
            repeat task.wait() until root()
            task.wait(0.1)
            if wasCrim and cpos then SwitchToCriminalAndReturn(cpos) end
        end

        if F.Prot.AntiTase and track.Animation.AnimationId=="rbxassetid://279227693" then
            local ws=normalWS; local jp=normalJP
            track:Stop(); track:Destroy()
            local h=hum()
            if h then h.PlatformStand=false; h.Sit=false; task.wait(); h.WalkSpeed=ws; h.JumpPower=jp end
            fixTools(); task.delay(0.2,fixTools); task.spawn(restoreSpeed,ws,jp)
        end
    end)

    charHum.Died:Connect(function()
        if F.Auto.AutoRespawn then
            local r=root(); if r then lastDeathCF=r.CFrame end
        end
    end)

    if lastDeathCF and F.Auto.AutoRespawn then
        task.wait(12)
        local r=root(); if r then r.CFrame=lastDeathCF end
    end
end)

local plTarget, plFollow, spectating, spectateTarget=nil,false,false,nil
local function stopSpectate() spectating=false; spectateTarget=nil; local mh=hum(); if mh then pcall(function() cam().CameraSubject=mh end) end end

local T={
    bg=Color3.fromRGB(22,22,25),title=Color3.fromRGB(16,16,19),panel=Color3.fromRGB(29,29,33),
    item=Color3.fromRGB(37,37,42),itemH=Color3.fromRGB(49,49,55),
    line=Color3.fromRGB(58,58,64),text=Color3.fromRGB(232,232,236),sub=Color3.fromRGB(148,148,155),
    accent=Color3.fromRGB(224,64,64),off=Color3.fromRGB(50,50,56),green=Color3.fromRGB(120,210,140),
}
local FONT=Enum.Font.Gotham
local BOLD=Enum.Font.GothamBold
local function make(cls,pr,par) local o=Instance.new(cls); for k,v in pairs(pr) do o[k]=v end; o.Parent=par; return o end
local function corner(o,r) return make("UICorner",{CornerRadius=UDim.new(0,r or 4)},o) end
local function stroke(o,col,t) return make("UIStroke",{Color=col or T.line,Thickness=t or 1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},o) end
local function tw(o,dur,props,style,dir)
    local ok,t=pcall(function() return Tween:Create(o,TweenInfo.new(dur or 0.15,style or Enum.EasingStyle.Quad,dir or Enum.EasingDirection.Out),props) end)
    if ok and t then t:Play() end; return t
end

local accentObjs={}
local accentRings={}
local fovCircle
local function reg(o,prop) accentObjs[#accentObjs+1]={o=o,p=prop or "BackgroundColor3"}; return o end
local function setAccent(col)
    T.accent=col
    for _,e in ipairs(accentObjs) do pcall(function() if e.o and e.o.Parent then e.o[e.p]=col end end) end
    for _,e in ipairs(accentRings) do pcall(function() e.st.Color=e.get() and col or T.line end) end
    if fovCircle then pcall(function() fovCircle.Color=col end) end
end

local gui=make("ScreenGui",{Name="syntax_"..tostring(math.random(1e5,1e6)),ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},(gethui and gethui()) or CoreGui)
pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)

local WIN_W,WIN_H=640,520
local win=make("Frame",{Size=UDim2.fromOffset(WIN_W,WIN_H),Position=UDim2.new(0.5,-WIN_W/2,0.5,-WIN_H/2),BackgroundColor3=T.bg,BorderSizePixel=0,ClipsDescendants=true},gui)
corner(win,7); stroke(win,T.line,1)
local curW,curH=WIN_W,WIN_H

local rez=make("Frame",{Size=UDim2.fromOffset(14,14),Position=UDim2.new(1,-16,1,-16),BackgroundColor3=T.line,BackgroundTransparency=0.25,BorderSizePixel=0,ZIndex=60,Active=true},win); corner(rez,3)
do local rz,rs,rsz
    rez.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then rz=true;rs=Vector2.new(i.Position.X,i.Position.Y);rsz=win.AbsoluteSize end end)
    bind(UIS.InputChanged,function(i) if rz and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=Vector2.new(i.Position.X,i.Position.Y)-rs
        curW=math.clamp(math.floor(rsz.X+d.X),470,1100); curH=math.clamp(math.floor(rsz.Y+d.Y),320,800)
        win.Size=UDim2.fromOffset(curW,curH) end end)
    bind(UIS.InputEnded,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then rz=false end end)
end

local bgHost=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=8},win)
local boxes={}
for i=1,22 do
    local sz=math.random(7,20)
    local b=make("Frame",{Size=UDim2.fromOffset(sz,sz),Position=UDim2.fromOffset(math.random(0,WIN_W),math.random(-WIN_H,WIN_H)),BackgroundColor3=Color3.fromRGB(120,120,132),BackgroundTransparency=0.86,BorderSizePixel=0,ZIndex=8,Rotation=math.random(0,45)},bgHost)
    corner(b,3); boxes[i]={f=b,spd=math.random(16,46),x=b.Position.X.Offset,y=b.Position.Y.Offset}
end

local titleBar=make("Frame",{Size=UDim2.new(1,0,0,34),BackgroundColor3=T.title,BorderSizePixel=0},win)
make("TextLabel",{Size=UDim2.fromOffset(160,34),Position=UDim2.fromOffset(12,0),BackgroundTransparency=1,Font=BOLD,Text="syntax",TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,TextSize=16},titleBar)
make("TextLabel",{Size=UDim2.fromOffset(160,34),Position=UDim2.fromOffset(78,1),BackgroundTransparency=1,Font=FONT,Text="·  v8.0  <3",TextColor3=T.sub,TextXAlignment=Enum.TextXAlignment.Left,TextSize=12},titleBar)
local closeB=make("TextButton",{Size=UDim2.fromOffset(26,20),Position=UDim2.new(1,-32,0,7),BackgroundColor3=T.item,BorderSizePixel=0,AutoButtonColor=false,Font=FONT,Text="X",TextColor3=T.sub,TextSize=12},titleBar); corner(closeB,4)
local minB=make("TextButton",{Size=UDim2.fromOffset(26,20),Position=UDim2.new(1,-62,0,7),BackgroundColor3=T.item,BorderSizePixel=0,AutoButtonColor=false,Font=FONT,Text="—",TextColor3=T.sub,TextSize=12},titleBar); corner(minB,4)
closeB.MouseEnter:Connect(function() tw(closeB,0.12,{BackgroundColor3=Color3.fromRGB(180,55,55)}) end)
closeB.MouseLeave:Connect(function() tw(closeB,0.12,{BackgroundColor3=T.item}) end)
minB.MouseEnter:Connect(function() tw(minB,0.12,{BackgroundColor3=T.itemH}) end)
minB.MouseLeave:Connect(function() tw(minB,0.12,{BackgroundColor3=T.item}) end)

do local drag,ds,sp
    bind(titleBar.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true;ds=i.Position;sp=win.Position end end)
    bind(UIS.InputChanged,function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-ds; win.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
    bind(UIS.InputEnded,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
end

local tabBar=make("Frame",{Size=UDim2.new(1,0,0,30),Position=UDim2.fromOffset(0,34),BackgroundColor3=T.title,BorderSizePixel=0},win)
make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,VerticalAlignment=Enum.VerticalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,2)},tabBar)
make("UIPadding",{PaddingLeft=UDim.new(0,8)},tabBar)
make("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.fromOffset(0,64),BackgroundColor3=T.line,BorderSizePixel=0},win)
local underline=reg(make("Frame",{Size=UDim2.fromOffset(0,2),Position=UDim2.fromOffset(0,62),BackgroundColor3=T.accent,BorderSizePixel=0,ZIndex=3},win))
local body=make("Frame",{Size=UDim2.new(1,0,1,-99),Position=UDim2.fromOffset(0,65),BackgroundTransparency=1},win)

local pages,tabBtns={},{}
local function moveUnderline(btn,instant)
    local x=btn.AbsolutePosition.X-win.AbsolutePosition.X; local w=btn.AbsoluteSize.X
    if instant then underline.Position=UDim2.fromOffset(x,62); underline.Size=UDim2.fromOffset(w,2)
    else tw(underline,0.2,{Position=UDim2.fromOffset(x,62),Size=UDim2.fromOffset(w,2)},Enum.EasingStyle.Quart) end
end
local function selectTab(n)
    for k,pg in pairs(pages) do pg.frame.Visible=(k==n) end
    for k,b in pairs(tabBtns) do b.lbl.TextColor3=(k==n) and T.text or T.sub end
    moveUnderline(tabBtns[n].lbl)
end
local function addTab(n)
    local b=make("TextButton",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,1,0),BackgroundTransparency=1,AutoButtonColor=false,Font=FONT,Text=n,TextColor3=T.sub,TextSize=12},tabBar)
    make("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)},b)
    b.MouseEnter:Connect(function() if tabBtns[n] and tabBtns[n].lbl.TextColor3~=T.text then tw(b,0.12,{TextColor3=T.text}) end end)
    b.MouseLeave:Connect(function()
        local active=false; for k,x in pairs(tabBtns) do if x.lbl==b then active=(pages[k].frame.Visible) end end
        if not active then tw(b,0.12,{TextColor3=T.sub}) end end)
    local frame=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false},body)
    local function col(px)
        local c=make("ScrollingFrame",{Position=UDim2.new(px,px==0 and 8 or 4,0,8),Size=UDim2.new(0.5,-12,1,-16),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=T.line,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y},frame)
        make("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},c); return c
    end
    local pg={frame=frame,left=col(0),right=col(0.5)}
    tabBtns[n]={lbl=b}; pages[n]=pg
    b.MouseButton1Click:Connect(function() selectTab(n) end)
    return pg
end

local function section(par,title)
    local s=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=T.panel,BorderSizePixel=0},par); corner(s,5); stroke(s,T.line,1)
    make("UIPadding",{PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,10),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)},s)
    make("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},s)
    reg(make("TextLabel",{Size=UDim2.new(1,0,0,16),BackgroundTransparency=1,Font=BOLD,Text=title,TextColor3=T.accent,TextXAlignment=Enum.TextXAlignment.Left,TextSize=12,LayoutOrder=-1},s),"TextColor3")
    return s
end
local function toggle(p,text,get,set)
    local r=make("Frame",{Size=UDim2.new(1,0,0,22),BackgroundTransparency=1},p)
    local ring=make("Frame",{Size=UDim2.fromOffset(15,15),Position=UDim2.new(0,0,0.5,-7),BackgroundTransparency=1,BorderSizePixel=0},r); corner(ring,8)
    local st=stroke(ring,get() and T.accent or T.line,1)
    accentRings[#accentRings+1]={st=st,get=get}
    local dt=reg(make("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(get() and 7 or 0,get() and 7 or 0),BackgroundColor3=T.accent,BackgroundTransparency=get() and 0 or 1,BorderSizePixel=0,Visible=get()},ring)); corner(dt,4)
    make("TextLabel",{Size=UDim2.new(1,-24,1,0),Position=UDim2.fromOffset(23,0),BackgroundTransparency=1,Font=FONT,Text=text,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,TextSize=12},r)
    local btn=make("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text=""},r)
    btn.MouseButton1Click:Connect(function()
        local v=not get(); set(v); st.Color=v and T.accent or T.line
        if v then dt.Visible=true; tw(dt,0.16,{Size=UDim2.fromOffset(7,7),BackgroundTransparency=0},Enum.EasingStyle.Back)
        else tw(dt,0.12,{Size=UDim2.fromOffset(0,0),BackgroundTransparency=1}); task.delay(0.14,function() if not get() then dt.Visible=false end end) end
    end)
end
local function slider(p,text,mn,mx,get,set)
    local r=make("Frame",{Size=UDim2.new(1,0,0,38),BackgroundTransparency=1},p)
    make("TextLabel",{Size=UDim2.new(1,-60,0,16),Position=UDim2.fromOffset(0,1),BackgroundTransparency=1,Font=FONT,Text=text,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,TextSize=12},r)
    local val=reg(make("TextLabel",{Size=UDim2.new(0,58,0,16),Position=UDim2.new(1,-58,0,1),BackgroundTransparency=1,Font=FONT,Text=tostring(get()),TextColor3=T.accent,TextXAlignment=Enum.TextXAlignment.Right,TextSize=12},r),"TextColor3")
    local track=make("Frame",{Size=UDim2.new(1,0,0,6),Position=UDim2.fromOffset(0,24),BackgroundColor3=T.off,BorderSizePixel=0},r); corner(track,3)
    local fill=reg(make("Frame",{Size=UDim2.new((get()-mn)/(mx-mn),0,1,0),BackgroundColor3=T.accent,BorderSizePixel=0},track)); corner(fill,3)
    local function setX(px,anim) local a=math.clamp((px-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        local v=math.floor((mn+(mx-mn)*a)*100)/100; val.Text=tostring(v); set(v)
        if anim then tw(fill,0.08,{Size=UDim2.new(a,0,1,0)}) else fill.Size=UDim2.new(a,0,1,0) end end
    local drag=false
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true;setX(i.Position.X,true) end end)
    bind(UIS.InputChanged,function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then setX(i.Position.X) end end)
    bind(UIS.InputEnded,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
end
local function button(p,text,cb)
    local b=make("TextButton",{Size=UDim2.new(1,0,0,26),BackgroundColor3=T.item,BorderSizePixel=0,AutoButtonColor=false,Font=FONT,Text=text,TextColor3=T.text,TextSize=12},p); corner(b,4); stroke(b,T.line,1)
    b.MouseButton1Click:Connect(cb)
    b.MouseEnter:Connect(function() tw(b,0.12,{BackgroundColor3=T.itemH}) end)
    b.MouseLeave:Connect(function() tw(b,0.12,{BackgroundColor3=T.item}) end)
    return b
end
local function label(p,text) return make("TextLabel",{Size=UDim2.new(1,0,0,15),BackgroundTransparency=1,Font=FONT,Text=text,TextColor3=T.sub,TextXAlignment=Enum.TextXAlignment.Left,TextSize=11,TextWrapped=true},p) end

local activeDrop,activeDropBtn=nil,nil
local function closeDrop()
    if activeDrop then local m=activeDrop; activeDrop=nil; activeDropBtn=nil
        tw(m,0.12,{Size=UDim2.fromOffset(m.AbsoluteSize.X,0)})
        task.delay(0.14,function() if m and m.Parent then m:Destroy() end end) end
end
local function dropdown(p,labelText,getOptions,getCurrent,onSet)
    local r=make("Frame",{Size=UDim2.new(1,0,0,24),BackgroundTransparency=1},p)
    make("TextLabel",{Size=UDim2.new(0.42,-4,1,0),BackgroundTransparency=1,Font=FONT,Text=labelText,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,TextSize=12},r)
    local btn=make("TextButton",{Size=UDim2.new(0.58,0,0,22),Position=UDim2.new(0.42,4,0.5,-11),BackgroundColor3=T.item,BorderSizePixel=0,AutoButtonColor=false,Font=FONT,Text=getCurrent().."   ▼",TextColor3=T.accent,TextSize=11},r); corner(btn,4); stroke(btn,T.line,1)
    reg(btn,"TextColor3")
    local function lbl2() btn.Text=getCurrent().."   ▼" end
    btn.MouseEnter:Connect(function() tw(btn,0.12,{BackgroundColor3=T.itemH}) end)
    btn.MouseLeave:Connect(function() tw(btn,0.12,{BackgroundColor3=T.item}) end)
    btn.MouseButton1Click:Connect(function()
        if activeDropBtn==btn then closeDrop(); return end
        closeDrop()
        local opts=getOptions(); local n=math.max(#opts,1)
        local rel=btn.AbsolutePosition-win.AbsolutePosition; local w=btn.AbsoluteSize.X
        local rowH=22; local full=math.min(n*rowH+4,158)
        local menu=make("Frame",{Size=UDim2.fromOffset(w,0),Position=UDim2.fromOffset(rel.X,rel.Y+btn.AbsoluteSize.Y+2),BackgroundColor3=T.panel,BorderSizePixel=0,ClipsDescendants=true,ZIndex=40},win); corner(menu,4); stroke(menu,T.line,1)
        local sc=make("ScrollingFrame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=T.line,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=40},menu)
        make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder},sc); make("UIPadding",{PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,2)},sc)
        for _,opt in ipairs(opts) do
            local row=make("TextButton",{Size=UDim2.new(1,0,0,rowH),BackgroundColor3=T.panel,BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false,Font=FONT,Text="  "..opt,TextColor3=(opt==getCurrent()) and T.accent or T.text,TextXAlignment=Enum.TextXAlignment.Left,TextSize=12,ZIndex=41},sc)
            row.MouseEnter:Connect(function() row.BackgroundTransparency=0; row.BackgroundColor3=T.itemH end)
            row.MouseLeave:Connect(function() row.BackgroundTransparency=1 end)
            row.MouseButton1Click:Connect(function() onSet(opt); lbl2(); closeDrop() end)
        end
        activeDrop=menu; activeDropBtn=btn
        tw(menu,0.14,{Size=UDim2.fromOffset(w,full)},Enum.EasingStyle.Quart)
    end)
    return {refresh=lbl2,btn=btn}
end
bind(UIS.InputBegan,function(i)
    if i.UserInputType~=Enum.UserInputType.MouseButton1 or not activeDrop then return end
    local p=Vector2.new(i.Position.X,i.Position.Y)
    local function inside(o) local ap,as=o.AbsolutePosition,o.AbsoluteSize; return p.X>=ap.X and p.X<=ap.X+as.X and p.Y>=ap.Y and p.Y<=ap.Y+as.Y end
    if not (inside(activeDrop) or (activeDropBtn and inside(activeDropBtn))) then closeDrop() end
end)

local footer=make("Frame",{Size=UDim2.new(1,0,0,34),Position=UDim2.new(0,0,1,-34),BackgroundColor3=T.title,BorderSizePixel=0},win)
make("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3=T.line,BorderSizePixel=0},footer)
local dot=make("Frame",{Size=UDim2.fromOffset(8,8),Position=UDim2.fromOffset(16,13),BackgroundColor3=T.green,BorderSizePixel=0},footer); corner(dot,4)
make("TextLabel",{Size=UDim2.new(1,-24,1,0),Position=UDim2.fromOffset(32,0),BackgroundTransparency=1,Font=FONT,Text=LocalPlayer.Name.."   ·   Prison Life   ·   v8.0",TextColor3=T.sub,TextXAlignment=Enum.TextXAlignment.Left,TextSize=12},footer)

do
    local pg=addTab("Dashboard")
    local sStat=section(pg.left,"Stats")
    make("TextLabel",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,Font=BOLD,Text=LocalPlayer.Name,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,TextSize=15},sStat)
    local teamLbl=make("TextLabel",{Size=UDim2.new(1,0,0,15),BackgroundTransparency=1,Font=FONT,Text="Team:  —",TextColor3=T.sub,TextXAlignment=Enum.TextXAlignment.Left,TextSize=12},sStat)
    local hpTxt=make("TextLabel",{Size=UDim2.new(1,0,0,14),BackgroundTransparency=1,Font=FONT,Text="HP  —",TextColor3=T.sub,TextXAlignment=Enum.TextXAlignment.Left,TextSize=11},sStat)
    local hpBg=make("Frame",{Size=UDim2.new(1,0,0,8),BackgroundColor3=T.off,BorderSizePixel=0},sStat); corner(hpBg,3)
    local hpFill=make("Frame",{Size=UDim2.new(1,0,1,0),BackgroundColor3=T.green,BorderSizePixel=0},hpBg); corner(hpFill,3)
    local function stat(name)
        local r=make("Frame",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1},sStat)
        make("TextLabel",{Size=UDim2.new(0.6,0,1,0),BackgroundTransparency=1,Font=FONT,Text=name,TextColor3=T.sub,TextXAlignment=Enum.TextXAlignment.Left,TextSize=12},r)
        return make("TextLabel",{Size=UDim2.new(0.4,0,1,0),Position=UDim2.new(0.6,0,0,0),BackgroundTransparency=1,Font=BOLD,Text="—",TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Right,TextSize=13},r)
    end
    local sAllies=stat("Allies alive"); local sEnemies=stat("Enemies alive")
    local sOnline=stat("Players online"); local sAliveN=stat("Players alive")

    local sDetect=section(pg.right,"Detection Status")
    local detItems={
        {text="Fly  —  Undetected",col=Color3.fromRGB(90,210,140)},
        {text="Aimbot  —  Undetected",col=Color3.fromRGB(90,210,140)},
        {text="Speed  —  Detected",col=Color3.fromRGB(235,80,80),warn="    ↳  Keep under ~50 WalkSpeed"},
        {text="ESP  —  Undetected",col=Color3.fromRGB(90,210,140)},
        {text="Noclip  —  Undetected",col=Color3.fromRGB(90,210,140)},
        {text="Silent Aim  —  Undetected",col=Color3.fromRGB(90,210,140)},
        {text="Fast Guns  —  Undetected",col=Color3.fromRGB(90,210,140)},
        {text="Rage TP Kill  —  Undetected",col=Color3.fromRGB(90,210,140)},
        {text="Anti-Arrest  —  Undetected",col=Color3.fromRGB(90,210,140)},
        {text="Anti-Tase  —  Undetected",col=Color3.fromRGB(90,210,140)},
        {text="Killaura  —  Undetected",col=Color3.fromRGB(90,210,140)},
        {text="TriggerBot  —  Undetected",col=Color3.fromRGB(90,210,140)},
        {text="Auto Arrest  —  Undetected",col=Color3.fromRGB(90,210,140)},
    }
    for _,item in ipairs(detItems) do
        make("TextLabel",{Size=UDim2.new(1,0,0,14),BackgroundTransparency=1,Font=BOLD,Text=item.text,TextColor3=item.col,TextXAlignment=Enum.TextXAlignment.Left,TextSize=11,TextWrapped=true},sDetect)
        if item.warn then make("TextLabel",{Size=UDim2.new(1,0,0,13),BackgroundTransparency=1,Font=FONT,Text=item.warn,TextColor3=Color3.fromRGB(235,160,60),TextXAlignment=Enum.TextXAlignment.Left,TextSize=10,TextWrapped=true},sDetect) end
    end

    local lastDash=0
    Hub._dashPage=pg.frame
    Hub._updateDash=function()
        if os.clock()-lastDash<0.25 then return end; lastDash=os.clock()
        teamLbl.Text="Team:  "..(LocalPlayer.Team and LocalPlayer.Team.Name or "—")
        local allies,enemies,aliveN=0,0,0
        for _,p in ipairs(Players:GetPlayers()) do
            local ok=alive(p); if ok then aliveN+=1 end
            if p~=LocalPlayer and ok then if isEnemy(p) then enemies+=1 elseif p.Team==LocalPlayer.Team then allies+=1 end end
        end
        sAllies.Text=tostring(allies); sEnemies.Text=tostring(enemies)
        sOnline.Text=tostring(#Players:GetPlayers()); sAliveN.Text=tostring(aliveN)
        local h=hum()
        if h then local r=math.clamp(h.Health/math.max(h.MaxHealth,1),0,1)
            hpFill.Size=UDim2.new(r,0,1,0)
            hpFill.BackgroundColor3=Color3.fromRGB(math.floor(230*(1-r))+40,math.floor(200*r)+40,90)
            hpTxt.Text="HP  "..math.floor(h.Health).." / "..math.floor(h.MaxHealth)
        else hpFill.Size=UDim2.new(0,0,1,0); hpTxt.Text="HP  —" end
    end
end

do
    local pg=addTab("Aimbot")
    local sA=section(pg.left,"Aimbot")
    toggle(sA,"Enabled (auto-latch)",function() return F.Aim.On end,function(v) F.Aim.On=v end)
    dropdown(sA,"Enemy mode",function() return ENEMY_MODES end,function() return ENEMY_MODES[enemyMode] end,function(opt) for i,v in ipairs(ENEMY_MODES) do if v==opt then enemyMode=i end end end)
    dropdown(sA,"Target part",function() return {"Head","Torso"} end,function() return F.Aim.Part end,function(opt) F.Aim.Part=opt end)
    toggle(sA,"Wall check",function() return F.Aim.WallCheck end,function(v) F.Aim.WallCheck=v end)
    toggle(sA,"Show FOV circle",function() return F.Aim.ShowFOV end,function(v) F.Aim.ShowFOV=v end)
    local sT=section(pg.right,"Tuning")
    slider(sT,"FOV (px)",30,400,function() return F.Aim.FOV end,function(v) F.Aim.FOV=v end)
    slider(sT,"Smoothness",0.05,1,function() return F.Aim.Smooth end,function(v) F.Aim.Smooth=v end)
    slider(sT,"Prediction",0,1,function() return F.Aim.Predict end,function(v) F.Aim.Predict=v end)

    local sSA=section(pg.left,"Silent Aim")
    toggle(sSA,"Enabled",function() return F.Aim.Silent end,function(v) F.Aim.Silent=v end)
    slider(sSA,"Hit chance",0,100,function() return F.Aim.HitChance end,function(v) F.Aim.HitChance=v end)
    slider(sSA,"Headshot chance",0,100,function() return F.Aim.HeadshotChance end,function(v) F.Aim.HeadshotChance=v end)

    local sTB=section(pg.right,"TriggerBot")
    toggle(sTB,"Enabled",function() return F.TB.On end,function(v)
        F.TB.On=v
        if v then startTriggerBot() else stopTriggerBot() end
    end)
    toggle(sTB,"Vehicle wallbang",function() return F.VWB.On end,function(v) F.VWB.On=v end)

    local sTrig=section(pg.right,"Triggerbot (legacy click)")
    toggle(sTrig,"Triggerbot (click-fire)",function() return F.Aim.Trigger end,function(v) F.Aim.Trigger=v end)
    slider(sTrig,"Trigger delay (ms)",0,300,function() return F.Aim.TrigDelay end,function(v) F.Aim.TrigDelay=v end)
end

local BONES={{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}
local ESP={}
do
    local hasDraw=false
    if Drawing and Drawing.new then
        local ok,probe=pcall(Drawing.new,"Square")
        if ok and probe then hasDraw=true; pcall(function() probe:Remove() end) end
    end
    local host=CoreGui
    if gethui then local ok,h=pcall(gethui); if ok and h then host=h end end
    host=host or LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local pool={}
    local function nd(k,pr) local d=Drawing.new(k); for a,b in pairs(pr) do d[a]=b end; return d end
    local function build(p)
        if hasDraw then
            local ok=pcall(function()
                local bones={}; for i=1,#BONES do bones[i]=nd("Line",{Thickness=1,Color=Color3.new(1,1,1)}) end
                pool[p]={box=nd("Square",{Thickness=1,Filled=false,Color=Color3.new(1,1,1)}),
                    boxo=nd("Square",{Thickness=3,Filled=false,Color=Color3.new(0,0,0)}),
                    name=nd("Text",{Size=13,Center=true,Outline=true,Color=Color3.new(1,1,1)}),
                    dist=nd("Text",{Size=12,Center=true,Outline=true,Color=Color3.fromRGB(190,190,190)}),
                    trac=nd("Line",{Thickness=1,Color=Color3.fromRGB(255,95,95)}),
                    hpbg=nd("Square",{Thickness=1,Filled=true,Color=Color3.fromRGB(15,15,15)}),
                    hp=nd("Square",{Thickness=1,Filled=true,Color=Color3.fromRGB(90,230,150)}),bones=bones}
            end)
            if ok and pool[p] then return end; hasDraw=false; pool[p]=nil
        end
        local ok2,hl=pcall(Instance.new,"Highlight")
        if ok2 and hl then
            hl.FillTransparency=0.55; hl.OutlineColor=Color3.fromRGB(255,95,95)
            hl.FillColor=Color3.fromRGB(255,95,95); hl.Adornee=p.Character
            pcall(function() hl.Parent=host end); pool[p]={hl=hl}
        end
    end
    local function hide(o)
        if o.hl then o.hl.Adornee=nil; return end
        o.box.Visible=false; o.boxo.Visible=false; o.name.Visible=false; o.dist.Visible=false
        o.trac.Visible=false; o.hpbg.Visible=false; o.hp.Visible=false
        for _,ln in ipairs(o.bones) do ln.Visible=false end
    end
    function ESP.clear(p) local o=pool[p]; if not o then return end
        if o.hl then o.hl:Destroy() else
            for _,d in ipairs({o.box,o.boxo,o.name,o.dist,o.trac,o.hpbg,o.hp}) do pcall(function() d:Remove() end) end
            for _,ln in ipairs(o.bones) do pcall(function() ln:Remove() end) end
        end; pool[p]=nil end
    function ESP.render()
        if not attached then for _,p in ipairs(Players:GetPlayers()) do local o=pool[p]; if o then hide(o) end end; return end
        for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then
            if not pool[p] then build(p) end
            local o=pool[p]; local ok,c,h=alive(p)
            local hrp=ok and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
            if not (F.ESP.On and hrp) then if o then hide(o) end
            elseif o.hl then o.hl.Adornee=c
            else
                local enemy=isEnemy(p)
                if F.ESP.EnemiesOnly and not enemy then hide(o); continue end
                local col=enemy and Color3.fromRGB(255,95,95) or Color3.fromRGB(90,230,150)
                local head=c:FindFirstChild("Head")
                local top=cam():WorldToViewportPoint((head and head.Position or hrp.Position)+Vector3.new(0,0.6,0))
                local bot=cam():WorldToViewportPoint(hrp.Position-Vector3.new(0,3.2,0))
                if top.Z>0 then
                    local h2=math.abs(top.Y-bot.Y); local w=h2*0.62; local x,y=top.X-w/2,top.Y
                    o.box.Visible=F.ESP.Box; o.boxo.Visible=F.ESP.Box; o.box.Filled=F.ESP.Filled; o.box.Transparency=F.ESP.Filled and 0.35 or 1
                    o.box.Size=Vector2.new(w,h2); o.box.Position=Vector2.new(x,y); o.boxo.Size=o.box.Size; o.boxo.Position=o.box.Position; o.box.Color=col
                    o.name.Visible=F.ESP.Name; o.name.Text=p.Name; o.name.Color=col; o.name.Position=Vector2.new(top.X,y-15)
                    o.dist.Visible=F.ESP.Dist; o.dist.Text=math.floor((cam().CFrame.Position-hrp.Position).Magnitude).."m"; o.dist.Position=Vector2.new(top.X,y+h2+1)
                    local hb=F.ESP.Health and h; o.hpbg.Visible=hb; o.hp.Visible=hb
                    if hb then local rr=math.clamp(h.Health/math.max(h.MaxHealth,1),0,1)
                        o.hpbg.Size=Vector2.new(3,h2); o.hpbg.Position=Vector2.new(x-6,y)
                        o.hp.Size=Vector2.new(3,h2*rr); o.hp.Position=Vector2.new(x-6,y+h2*(1-rr))
                        o.hp.Color=Color3.fromRGB(math.floor(255*(1-rr)),math.floor(220*rr+35),80) end
                    o.trac.Visible=F.ESP.Tracer
                    if F.ESP.Tracer then o.trac.Color=col; local vp=cam().ViewportSize; o.trac.From=Vector2.new(vp.X/2,vp.Y); o.trac.To=Vector2.new(top.X,y+h2) end
                else hide(o) end
                if F.ESP.Skeleton then
                    for i,pair in ipairs(BONES) do
                        local pa=c:FindFirstChild(pair[1]); local pb=c:FindFirstChild(pair[2]); local ln=o.bones[i]
                        if pa and pb then
                            local sa=cam():WorldToViewportPoint(pa.Position); local sb=cam():WorldToViewportPoint(pb.Position)
                            if sa.Z>0 and sb.Z>0 then ln.Visible=true; ln.Color=col; ln.From=Vector2.new(sa.X,sa.Y); ln.To=Vector2.new(sb.X,sb.Y)
                            else ln.Visible=false end
                        else ln.Visible=false end
                    end
                else for _,ln in ipairs(o.bones) do ln.Visible=false end end
            end
        end end
    end
    function ESP.destroy() for p in pairs(pool) do ESP.clear(p) end end

    local epg=addTab("ESP")
    local sE=section(epg.left,"ESP")
    toggle(sE,"Enabled",function() return F.ESP.On end,function(v) F.ESP.On=v end)
    toggle(sE,"Enemies only",function() return F.ESP.EnemiesOnly end,function(v) F.ESP.EnemiesOnly=v end)
    toggle(sE,"Boxes",function() return F.ESP.Box end,function(v) F.ESP.Box=v end)
    toggle(sE,"Filled boxes",function() return F.ESP.Filled end,function(v) F.ESP.Filled=v end)
    toggle(sE,"Names",function() return F.ESP.Name end,function(v) F.ESP.Name=v end)
    local sV=section(epg.right,"Details")
    toggle(sV,"Distance",function() return F.ESP.Dist end,function(v) F.ESP.Dist=v end)
    toggle(sV,"Health bars",function() return F.ESP.Health end,function(v) F.ESP.Health=v end)
    toggle(sV,"Tracers",function() return F.ESP.Tracer end,function(v) F.ESP.Tracer=v end)
    toggle(sV,"Skeleton",function() return F.ESP.Skeleton end,function(v) F.ESP.Skeleton=v end)
end

do
    local pg=addTab("Combat")
    local sT=section(pg.left,"Target")
    local plInfo=label(sT,"TARGET:  none")
    local function tgtRoot() local tc=plTarget and plTarget.Character; return tc and (tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Torso")) end
    Hub._tgtRoot=tgtRoot
    local function refreshInfo()
        if plTarget and plTarget.Parent then local _,_,h=alive(plTarget)
            plInfo.Text="TARGET:  "..plTarget.Name.."\n"..(plTarget.Team and plTarget.Team.Name or "no team").."  ·  HP "..(h and math.floor(h.Health) or "?")
        else plInfo.Text="TARGET:  none" end
    end
    local function playerNames() local l={}; for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then l[#l+1]=p.Name end end; return l end
    local dropRef=dropdown(sT,"Select",playerNames,function() return plTarget and plTarget.Name or "none" end,function(name) plTarget=Players:FindFirstChild(name); refreshInfo() end)
    button(sT,"Refresh",refreshInfo)

    local sAc=section(pg.right,"Actions")
    button(sAc,"RAGE  (arm + TP + kill)",function()
        if not plTarget then Notify("Select a target first") return end
        if Hub._raging and Hub._raging() then return end
        doRage(plTarget)
    end)
    label(sAc,"grabs a gun, blinks on target, empties mag")
    button(sAc,"Kill Self",killSelf)
    button(sAc,"Spectate (toggle)",function()
        if spectating then stopSpectate(); return end
        if not plTarget then return end
        spectateTarget=plTarget; spectating=true
    end)
    button(sAc,"Stop Spectating",stopSpectate)
    button(sAc,"TP in front",function() local tr=tgtRoot(); if tr then tpMove(tr.CFrame*CFrame.new(0,0,-3)) end end)
    button(sAc,"TP behind",function() local tr=tgtRoot(); if tr then tpMove(tr.CFrame*CFrame.new(0,0,3)) end end)
    button(sAc,"TP on top",function() local tr=tgtRoot(); if tr then tpMove(tr.CFrame*CFrame.new(0,4,0)) end end)
    toggle(sAc,"Follow target",function() return plFollow end,function(v) plFollow=v end)

    local sKA=section(pg.left,"Killaura")
    toggle(sKA,"Enabled",function() return F.KA.On end,function(v)
        F.KA.On=v
        if v then startKillaura() else stopKillaura() end
    end)
    slider(sKA,"Range (studs)",1,20,function() return F.KA.Range end,function(v) F.KA.Range=v end)
    slider(sKA,"Max targets",1,10,function() return F.KA.MaxTargets end,function(v) F.KA.MaxTargets=math.floor(v) end)
    slider(sKA,"Angle",1,360,function() return F.KA.Angle end,function(v) F.KA.Angle=v end)
    toggle(sKA,"Require mouse down",function() return F.KA.RequireMouse end,function(v) F.KA.RequireMouse=v end)
end

do
    local pg=addTab("Character")
    local sS=section(pg.left,"Speed / Jump")
    toggle(sS,"Speed",function() return F.Mov.Speed end,function(v) F.Mov.Speed=v; local h=hum(); if h and not v then h.WalkSpeed=16 end end)
    slider(sS,"Walk speed",16,250,function() return F.Mov.SpeedV end,function(v) F.Mov.SpeedV=v end)
    toggle(sS,"Jump power",function() return F.Mov.JumpOn end,function(v) F.Mov.JumpOn=v; local h=hum(); if h and not v then h.UseJumpPower=true; h.JumpPower=50 end end)
    slider(sS,"Jump power value",50,400,function() return F.Mov.JumpV end,function(v) F.Mov.JumpV=v end)
    toggle(sS,"Infinite jump",function() return F.Mov.InfJump end,function(v) F.Mov.InfJump=v end)

    local sF=section(pg.right,"Fly / Noclip")
    toggle(sF,"Fly (WASD Space/Ctrl)",function() return F.Mov.Fly end,function(v) F.Mov.Fly=v end)
    slider(sF,"Fly speed",0.5,10,function() return F.Mov.FlyV end,function(v) F.Mov.FlyV=v end)
    toggle(sF,"Fly noclip",function() return F.Mov.FlyNoclip end,function(v) F.Mov.FlyNoclip=v end)
    toggle(sF,"Noclip (standalone)",function() return F.Mov.Noclip end,function(v) F.Mov.Noclip=v; if v then applyNoclip() else stopNoclip() end end)
    toggle(sF,"Snack noclip",function() return F.Mov.NcGlitch end,function(v) F.Mov.NcGlitch=v; if not v and CharacterCollision then pcall(function() CharacterCollision.Enabled=true end) end end)
    toggle(sF,"Disabler (fixes phase)",function() return F.DIS.On end,function(v)
        F.DIS.On=v
        if v then setupDisabler() else stopDisabler() end
    end)

    local sV=section(pg.left,"Vehicle")
    toggle(sV,"Car Fly",function() return F.Mov.CarFly end,function(v) F.Mov.CarFly=v; setupCarFly() end)
    slider(sV,"Car fly speed",20,300,function() return F.Mov.CarFlySpeed end,function(v) F.Mov.CarFlySpeed=v end)

    local sM=section(pg.right,"Misc")
    toggle(sM,"Spin",function() return F.Mov.Spin end,function(v) F.Mov.Spin=v; if v then applySpin() else stopSpin() end end)
    slider(sM,"Spin speed",1,20,function() return F.Mov.SpinV end,function(v) F.Mov.SpinV=v; if F.Mov.Spin then applySpin() end end)
    slider(sM,"Camera FOV",40,120,function() return F.Wld.FOV end,function(v) F.Wld.FOV=v; pcall(function() cam().FieldOfView=v end) end)

    local sE=section(pg.right,"Escape")
    toggle(sE,"Auto Escape (≤30% HP → tree)",function() return F.Esc.AutoEscape end,function(v) F.Esc.AutoEscape=v; setupAutoEscape() end)
    button(sE,"Escape to tree now",TeleportToTree)
end

do
    local pg=addTab("Protection")
    local sP=section(pg.left,"Anti")
    toggle(sP,"Anti-Arrest (die + stay criminal)",function() return F.Prot.AntiArrest end,function(v) F.Prot.AntiArrest=v end)
    toggle(sP,"Anti-Tase (clear tase instantly)",function() return F.Prot.AntiTase end,function(v) F.Prot.AntiTase=v end)
    toggle(sP,"Anti-Tase v2 (hook PlayerTased)",function() return F.AT.On end,function(v)
        F.AT.On=v
        setupAntiTaze()
    end)
    toggle(sP,"Anti-Void",function() return F.Prot.AntiVoid end,function(v) F.Prot.AntiVoid=v end)
    toggle(sP,"Keep reset button enabled",function() return F.Prot.EnableReset end,function(v) F.Prot.EnableReset=v end)

    local sAA=section(pg.right,"Auto Arrest")
    toggle(sAA,"Enabled",function() return F.AA.On end,function(v)
        F.AA.On=v
        if v then startAutoArrest() else stopAutoArrest() end
    end)
    slider(sAA,"Range (studs)",1,15,function() return F.AA.Range end,function(v) F.AA.Range=v end)
    toggle(sAA,"Require handcuffs equipped",function() return F.AA.HandCheck end,function(v) F.AA.HandCheck=v end)
    toggle(sAA,"Arrest Inmates",function() return F.AA.InmatesEnabled end,function(v) F.AA.InmatesEnabled=v end)
    toggle(sAA,"Arrest Criminals",function() return F.AA.CriminalsEnabled end,function(v) F.AA.CriminalsEnabled=v end)

    local sEsc=section(pg.right,"Auto Escape")
    toggle(sEsc,"Auto Escape (≤30% HP → tree)",function() return F.Esc.AutoEscape end,function(v) F.Esc.AutoEscape=v; setupAutoEscape() end)
    button(sEsc,"Escape to tree now",TeleportToTree)

    local sF=section(pg.left,"Feed")
    toggle(sF,"Kill feed notifications",function() return F.Feed.Kill end,function(v) F.Feed.Kill=v end)
    toggle(sF,"Hostile / trespassing alerts",function() return F.Feed.Hostile end,function(v) F.Feed.Hostile=v end)
end

do
    local pg=addTab("Automation")
    local sG=section(pg.left,"Guns")
    toggle(sG,"Fast guns (hookmetamethod)",function() return F.Auto.FastGuns end,function(v) F.Auto.FastGuns=v end)
    slider(sG,"Fire rate override",0,100,function() return F.Auto.FireRate end,function(v) F.Auto.FireRate=v end)
    toggle(sG,"Auto guns on spawn",function() return F.Auto.Guns end,function(v) F.Auto.Guns=v end)

    local _selectedGun=nil
    dropdown(sG,"Gun",function() return allGuns end,function() return _selectedGun or "select" end,function(opt) _selectedGun=opt end)
    button(sG,"Add/Remove from auto-gun list",function()
        if not _selectedGun then return end
        local idx=table.find(F.Auto.GunList,_selectedGun)
        if idx then table.remove(F.Auto.GunList,idx); Notify("Removed "..(_selectedGun).." from list")
        else table.insert(F.Auto.GunList,_selectedGun); Notify("Added ".._selectedGun.." to list") end
    end)
    button(sG,"Get gun now",function()
        if not _selectedGun then return end
        local r=root(); local save=r and r.CFrame
        GetGun(_selectedGun)
        if r and save then r.CFrame=save end
    end)
    button(sG,"Get all accessible guns",function()
        local r=root(); local save=r and r.CFrame
        for _,g in ipairs(allGuns) do if not GetTool(g) then GetGun(g) end; task.wait(0.3) end
        if r and save then r.CFrame=save end
    end)

    local sGM=section(pg.right,"Gun Modifications")
    toggle(sGM,"Enabled",function() return F.GM.On end,function(v) F.GM.On=v end)
    toggle(sGM,"No spread",function() return F.GM.NoSpread end,function(v) F.GM.NoSpread=v end)
    toggle(sGM,"Full auto",function() return F.GM.FullAuto end,function(v) F.GM.FullAuto=v end)
    slider(sGM,"Fire rate multiplier",1,100,function() return F.GM.FireRate end,function(v) F.GM.FireRate=v end)

    local sP=section(pg.right,"Prison")
    toggle(sP,"Auto break toilets (needs hammer)",function() return F.Auto.Toilets end,function(v) F.Auto.Toilets=v end)
    toggle(sP,"Keycard grabber",function() return F.Auto.Keycard end,function(v) F.Auto.Keycard=v; if v then startKeycard() else _kcRunning=false end end)
    toggle(sP,"No-collision doors",function() return F.Auto.Doors end,function(v) F.Auto.Doors=v; if not v then AddDoors() end end)
    toggle(sP,"Transparent doors",function() return F.Auto.TDoors end,function(v) F.Auto.TDoors=v; if not v then TransparentDoors(false) end end)
    toggle(sP,"Auto anti-jump removal",function() return F.Auto.AJR end,function(v) F.Auto.AJR=v end)
    toggle(sP,"Auto respawn (respawn in place)",function() return F.Auto.AutoRespawn end,function(v) F.Auto.AutoRespawn=v end)
    toggle(sP,"Old gun sounds",function() return F.Auto.OldSounds end,function(v) F.Auto.OldSounds=v end)
    toggle(sP,"Old gun sounds (self only)",function() return F.Auto.OldSoundsMe end,function(v) F.Auto.OldSoundsMe=v end)
end

do
    local pg=addTab("World")
    local sL=section(pg.left,"Lighting")
    toggle(sL,"Fullbright",function() return F.Wld.Fullbright end,function(v) F.Wld.Fullbright=v; fullbright(v) end)
    toggle(sL,"No fog",function() return F.Wld.NoFog end,function(v) F.Wld.NoFog=v; if v then Lighting.FogEnd=1e9 end end)
    toggle(sL,"Hide trees",function() return false end,function(v) hideTrees(v) end)

    local sMap=section(pg.left,"Map Destroy")
    label(sMap,"CLIENT-SIDE — rejoin to undo")
    button(sMap,"No-collision doors",NoDoors)
    button(sMap,"Transparent doors",function() TransparentDoors(true) end)
    button(sMap,"Destroy doors",DestroyDoors)
    button(sMap,"Unkillable fence (strip damage)",UkFence)
    button(sMap,"Destroy fences",DestroyFences)
    button(sMap,"Destroy gates",DestroyGates)
    button(sMap,"Destroy team indicators",function() pcall(function() Workspace.TeamIndicators:Destroy() end) end)
    button(sMap,"Break all toilets",BreakAllToilets)
    button(sMap,"Remove jump cooldown",ajr)

    local sIt=section(pg.right,"Item Grabber")
    local itemMap={}
    local function scanNames()
        itemMap={}
        for _,d in ipairs(Workspace:GetDescendants()) do
            local tn=d:GetAttribute("ToolName")
            if tn and not itemMap[tn] then
                local part=d:IsA("BasePart") and d or d:FindFirstChildWhichIsA("BasePart",true)
                if part then itemMap[tn]=part end
            end
        end
        local ns={}; for n in pairs(itemMap) do ns[#ns+1]=n end; table.sort(ns); return ns
    end
    local selItem
    dropdown(sIt,"Item",scanNames,function() return selItem or "scan first" end,function(opt) selItem=opt end)
    button(sIt,"Scan items",function() scanNames(); Notify("Scanned "..tostring(#(function() local k=0; for _ in pairs(itemMap) do k+=1 end; return k end)()).." items") end)
    button(sIt,"Grab selected",function()
        if not selItem then return end
        local part=itemMap[selItem]; local r=root(); if not (part and part.Parent and r) then return end
        local save=r.CFrame
        pcall(function() r.CFrame=CFrame.new(part.Position+Vector3.new(0,2.5,0)) end); task.wait(0.18)
        pcall(function() if GiverRemote then GiverRemote:FireServer(part) end end)
        pcall(function() if GiverRemote and part.Parent then GiverRemote:FireServer(part.Parent) end end)
        pcall(function() if InteractItem then InteractItem:InvokeServer(part) end end)
        task.wait(0.12); pcall(function() r.CFrame=save end)
    end)

    local sSv=section(pg.right,"Server")
    toggle(sSv,"Anti-AFK",function() return F.Wld.AntiAFK end,function(v) F.Wld.AntiAFK=v end)
    button(sSv,"Rejoin",function()
        pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,game.JobId,LocalPlayer) end)
    end)
    button(sSv,"Server hop",function()
        pcall(function()
            local TS=game:GetService("TeleportService"); local HS=game:GetService("HttpService")
            local data=HS:JSONDecode(game:HttpGetAsync("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"))
            for _,s in ipairs(data.data) do
                if s.playing<s.maxPlayers and s.id~=game.JobId then TS:TeleportToPlaceInstance(game.PlaceId,s.id,LocalPlayer); return end
            end
            Notify("No open servers found")
        end)
    end)
end

do
    local pg=addTab("Teleport")
    local function tp(pos) tpMove(CFrame.new(pos)) end
    local sLoc=section(pg.left,"Prison")
    button(sLoc,"Criminal Base",function() tp(Vector3.new(-975,106,2058)) end)
    button(sLoc,"Criminal Armory",function() tp(Vector3.new(-928,93,2038)) end)
    button(sLoc,"Neutral Spawn",function() tp(Vector3.new(879,36,2349)) end)
    button(sLoc,"Prison Cells",function() tp(Vector3.new(917,98,2435)) end)
    button(sLoc,"Guard Armory",function() tp(Vector3.new(836,99,2229)) end)
    button(sLoc,"Nexus",function() tp(Vector3.new(877,99,2373)) end)
    button(sLoc,"Cafeteria",function() tp(Vector3.new(884,99,2293)) end)
    button(sLoc,"Kitchen",function() tp(Vector3.new(936,99,2224)) end)
    button(sLoc,"Yard",function() tp(Vector3.new(787,97,2468)) end)
    button(sLoc,"Roof",function() tp(Vector3.new(918,139,2266)) end)
    button(sLoc,"Sewers",function() tp(Vector3.new(917,78,2297)) end)
    button(sLoc,"Garage",function() tp(Vector3.new(618,98,2469)) end)
    button(sLoc,"Vents",function() tp(Vector3.new(933,121,2232)) end)
    button(sLoc,"Secret Room/Office",function() tp(Vector3.new(706,103,2344)) end)
    button(sLoc,"Yard Tower",function() tp(Vector3.new(786,125,2587)) end)
    button(sLoc,"Left Front Wall",function() tp(Vector3.new(505,125,2127)) end)
    button(sLoc,"Void Baseplate",function() tp(Vector3.new(872,38,2344)) end)
    local sOuter=section(pg.right,"Outside")
    button(sOuter,"Neighbourhood",function() tp(Vector3.new(-281,54,2484)) end)
    button(sOuter,"Gas Station",function() tp(Vector3.new(-497,54,1686)) end)
    button(sOuter,"Lakeside Grocer",function() tp(Vector3.new(455,11,1222)) end)
    button(sOuter,"Roadend by Prison",function() tp(Vector3.new(1060,67,1847)) end)
    button(sOuter,"Roadend by Warehouse",function() tp(Vector3.new(-979,54,1382)) end)
    button(sOuter,"Big Building Roof",function() tp(Vector3.new(-317,118,2009)) end)
    local sTrap=section(pg.right,"Traps")
    label(sTrap,"teleports enemies to enclosed spaces")
    button(sTrap,"Big Building Trap",function() tp(Vector3.new(-306,84,1984)) end)
    button(sTrap,"Inside Shops",function() tp(Vector3.new(-315,64,1840)) end)
    button(sTrap,"Other Warehouse",function() tp(Vector3.new(-943,94,1919)) end)

    local sWp=section(pg.left,"Waypoints")
    label(sWp,"T = click-TP to cursor")
    local wpCount=0
    button(sWp,"Save waypoint here",function()
        local r=root(); if not r then return end
        local wp=r.CFrame; wpCount+=1; local id=wpCount
        local row=make("Frame",{Size=UDim2.new(1,0,0,26),BackgroundColor3=T.item,BorderSizePixel=0},sWp); corner(row,4); stroke(row,T.line,1)
        local tpb=make("TextButton",{Size=UDim2.new(1,-32,1,0),Position=UDim2.fromOffset(10,0),BackgroundTransparency=1,Font=FONT,Text="› Waypoint "..id,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,TextSize=12},row)
        tpb.MouseButton1Click:Connect(function() tpMove(wp) end)
        local del=make("TextButton",{Size=UDim2.fromOffset(22,18),Position=UDim2.new(1,-26,0.5,-9),BackgroundColor3=T.off,BorderSizePixel=0,AutoButtonColor=false,Font=FONT,Text="X",TextColor3=T.text,TextSize=11},row); corner(del,4)
        del.MouseEnter:Connect(function() tw(del,0.12,{BackgroundColor3=Color3.fromRGB(180,60,60)}) end)
        del.MouseLeave:Connect(function() tw(del,0.12,{BackgroundColor3=T.off}) end)
        del.MouseButton1Click:Connect(function() row:Destroy() end)
    end)
end

do
    local pg=addTab("Settings")
    local sC=section(pg.left,"Accent Color")
    local presets={{"Red",224,64,64},{"Pink",232,120,190},{"Blue",70,140,235},{"Green",90,200,130},{"Orange",235,145,60},{"Purple",165,110,235},{"Cyan",80,205,215},{"White",232,232,236}}
    local swatchRow=make("Frame",{Size=UDim2.new(1,0,0,26),BackgroundTransparency=1},sC)
    make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},swatchRow)
    local rV,gV,bV=224,64,64; local rF,gF,bF
    for _,pr in ipairs(presets) do
        local col=Color3.fromRGB(pr[2],pr[3],pr[4])
        local sw=make("TextButton",{Size=UDim2.fromOffset(24,24),BackgroundColor3=col,BorderSizePixel=0,AutoButtonColor=false,Text=""},swatchRow); corner(sw,5); stroke(sw,T.line,1)
        sw.MouseButton1Click:Connect(function() rV,gV,bV=pr[2],pr[3],pr[4]; setAccent(col); if rF then rF(rV) end; if gF then gF(gV) end; if bF then bF(bV) end end)
        sw.MouseEnter:Connect(function() tw(sw,0.1,{Size=UDim2.fromOffset(27,27)}) end)
        sw.MouseLeave:Connect(function() tw(sw,0.1,{Size=UDim2.fromOffset(24,24)}) end)
    end
    local function cslider(text,init,setC)
        local r=make("Frame",{Size=UDim2.new(1,0,0,34),BackgroundTransparency=1},sC)
        make("TextLabel",{Size=UDim2.new(1,-44,0,15),BackgroundTransparency=1,Font=FONT,Text=text,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,TextSize=12},r)
        local val=make("TextLabel",{Size=UDim2.new(0,42,0,15),Position=UDim2.new(1,-42,0,0),BackgroundTransparency=1,Font=FONT,Text=tostring(init),TextColor3=T.sub,TextXAlignment=Enum.TextXAlignment.Right,TextSize=12},r)
        local track=make("Frame",{Size=UDim2.new(1,0,0,6),Position=UDim2.fromOffset(0,22),BackgroundColor3=T.off,BorderSizePixel=0},r); corner(track,3)
        local fill=reg(make("Frame",{Size=UDim2.new(init/255,0,1,0),BackgroundColor3=T.accent,BorderSizePixel=0},track)); corner(fill,3)
        local drag=false
        local function setX(px) local a=math.clamp((px-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
            local v=math.floor(a*255); fill.Size=UDim2.new(a,0,1,0); val.Text=tostring(v); setC(v) end
        track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true;setX(i.Position.X) end end)
        bind(UIS.InputChanged,function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then setX(i.Position.X) end end)
        bind(UIS.InputEnded,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
        return function(v) fill.Size=UDim2.new(v/255,0,1,0); val.Text=tostring(v) end
    end
    rF=cslider("R",rV,function(v) rV=v; setAccent(Color3.fromRGB(rV,gV,bV)) end)
    gF=cslider("G",gV,function(v) gV=v; setAccent(Color3.fromRGB(rV,gV,bV)) end)
    bF=cslider("B",bV,function(v) bV=v; setAccent(Color3.fromRGB(rV,gV,bV)) end)
    toggle(sC,"Falling boxes",function() return F.UI.Boxes end,function(v) F.UI.Boxes=v; bgHost.Visible=v end)
    toggle(sC,"RGB accent",function() return F.UI.RGB end,function(v) F.UI.RGB=v end)
    local sI=section(pg.right,"Controls")
    label(sI,"Right Shift  —  toggle UI")
    label(sI,"T  —  click-TP to cursor")
    label(sI,"Fly:  WASD + Space / Ctrl")
    label(sI,"Car Fly:  get in a vehicle first")
    label(sI,"Aimbot:  auto-latch in Aimbot tab")
    label(sI,"Rage:  Combat tab → select → RAGE")
    button(sI,"Unload",function() Hub._unload() end)
end

selectTab("Dashboard")
task.defer(function() RunService.RenderStepped:Wait(); pcall(function() moveUnderline(tabBtns["Dashboard"].lbl,true) end) end)

local minimized=false
minB.MouseButton1Click:Connect(function()
    minimized=not minimized
    tabBar.Visible=not minimized; body.Visible=not minimized; footer.Visible=not minimized
    bgHost.Visible=(not minimized) and F.UI.Boxes; underline.Visible=not minimized
    tw(win,0.2,{Size=minimized and UDim2.fromOffset(curW,34) or UDim2.fromOffset(curW,curH)},Enum.EasingStyle.Quart)
    minB.Text=minimized and "+" or "—"
end)
closeB.MouseButton1Click:Connect(function() Hub._unload() end)

pcall(function()
    if not (Drawing and Drawing.new) then return end
    fovCircle=Drawing.new("Circle"); fovCircle.Thickness=1; fovCircle.NumSides=52
    fovCircle.Color=T.accent; fovCircle.Filled=false; fovCircle.Visible=false
end)

bind(UIS.InputBegan,function(i,gpe)
    if i.UserInputType==Enum.UserInputType.MouseButton2 then F.Aim.Held=true end
    if gpe then return end
    if i.UserInputType==Enum.UserInputType.MouseButton1 then F.Aim.Fire=true end
    if i.KeyCode==Enum.KeyCode.RightShift then win.Visible=not win.Visible end
    if i.KeyCode==Enum.KeyCode.T then local m=LocalPlayer:GetMouse(); if m.Hit then tpMove(CFrame.new(m.Hit.Position+Vector3.new(0,3,0))) end end
    if F.Mov.InfJump and i.KeyCode==Enum.KeyCode.Space then local h=hum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
    if F.Mov.NcGlitch and i.KeyCode==Enum.KeyCode.Space then _ncLastJump=tick() end
end)
bind(UIS.InputEnded,function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton2 then F.Aim.Held=false end
    if i.UserInputType==Enum.UserInputType.MouseButton1 then F.Aim.Fire=false end
end)

pcall(function()
    local vu=game:GetService("VirtualUser")
    bind(LocalPlayer.Idled,function() if F.Wld.AntiAFK then vu:CaptureController(); vu:ClickButton2(Vector2.new()) end end)
end)

bind(Players.PlayerRemoving,function(p)
    pcall(function() ESP.clear(p) end)
    if p==plTarget then plTarget=nil; plFollow=false end
end)

bind(RunService.Stepped,function()
    if attached and F.Mov.Noclip then
        local c=char()
        if c then for _,v in ipairs(c:GetDescendants()) do if v:IsA("BasePart") and v.CanCollide then v.CanCollide=false end end end
    end
end)

bind(RunService.Heartbeat,function()
    if F.Prot.AntiVoid then
        pcall(function()
            local r=root()
            if r and r.Position.Y < -7 then
                r.CFrame=CFrame.new(r.Position.X,100,r.Position.Z)
                r.AssemblyLinearVelocity=Vector3.new(r.AssemblyLinearVelocity.X,0,r.AssemblyLinearVelocity.Z)
            end
        end)
    end

    if F.Prot.EnableReset then pcall(function() StarterGui:SetCore("ResetButtonCallback",true) end) end

    if F.Auto.Toilets then hammerCheck() end
    if F.Auto.Doors then NoDoors() end
    if F.Auto.TDoors then TransparentDoors(true) end

    if F.Auto.Guns and not _autoGunRunning and root() then
        if os.clock()-_autoGunLst >= AUTOGUN_DELAY then
            _autoGunRunning=true
            local r=root(); local save=r and r.CFrame
            task.spawn(function()
                for _,g in ipairs(F.Auto.GunList) do
                    if not GetTool(g) then GetGun(g) end; task.wait(0.3)
                end
                if r and save then pcall(function() r.CFrame=save end) end
                _autoGunRunning=false
            end)
        end
    end
end)

local lastFire=0
local lastDash=0
local rgbHue=0

bind(RunService.RenderStepped,function(dt)
    if win.Visible and F.UI.Boxes and bgHost.Visible then
        for _,bx in ipairs(boxes) do
            bx.y=bx.y+bx.spd*dt
            if bx.y>WIN_H+24 then bx.y=-24-math.random(0,80); bx.x=math.random(0,WIN_W) end
            bx.f.Position=UDim2.fromOffset(bx.x,bx.y)
        end
    end

    if F.UI.RGB and win.Visible then rgbHue=(rgbHue+dt*0.14)%1; pcall(setAccent,Color3.fromHSV(rgbHue,0.72,1)) end

    pcall(ESP.render)

    if Hub._dashPage and Hub._dashPage.Visible and win.Visible and Hub._updateDash then
        pcall(Hub._updateDash)
    end

    if spectating then
        local st=spectateTarget; local tc=st and st.Character; local th=tc and tc:FindFirstChildOfClass("Humanoid")
        if th and th.Health>0 then pcall(function() cam().CameraSubject=th end) else stopSpectate() end
    end
    if not attached then if fovCircle then fovCircle.Visible=false end; return end

    local h,r=hum(),root()
    if h then
        if F.Mov.Speed then h.WalkSpeed=F.Mov.SpeedV end
        if F.Mov.JumpOn then h.UseJumpPower=true; h.JumpPower=F.Mov.JumpV end
    end
    if F.Mov.Fly and r then
        local c=cam().CFrame; local d=Vector3.zero
        if key(Enum.KeyCode.W) then d+=c.LookVector end
        if key(Enum.KeyCode.S) then d-=c.LookVector end
        if key(Enum.KeyCode.A) then d-=c.RightVector end
        if key(Enum.KeyCode.D) then d+=c.RightVector end
        if key(Enum.KeyCode.Space) then d+=Vector3.new(0,1,0) end
        if key(Enum.KeyCode.LeftControl) then d-=Vector3.new(0,1,0) end
        if d.Magnitude>0 then r.CFrame=r.CFrame+d.Unit*(F.Mov.FlyV*50)*dt end
        r.AssemblyLinearVelocity=Vector3.zero
        if F.Mov.FlyNoclip then
            local ch=char()
            if ch then for _,v in ipairs(ch:GetDescendants()) do if v:IsA("BasePart") then pcall(function() v.CanCollide=false end) end end end
        end
    end

    if F.Wld.NoFog then Lighting.FogEnd=1e9 end

    if plFollow and Hub._tgtRoot then local rr=root(); local tr=Hub._tgtRoot(); if rr and tr then rr.CFrame=tr.CFrame*CFrame.new(0,0,3.5) end end

    if fovCircle then fovCircle.Visible=F.Aim.On and F.Aim.ShowFOV; fovCircle.Radius=F.Aim.FOV; fovCircle.Position=aimOrigin() end

    if F.Aim.On then
        local t=Aim.getTarget()
        if t then local aimPos=t.Position+t.AssemblyLinearVelocity*F.Aim.Predict
            local cf=cam().CFrame; cam().CFrame=cf:Lerp(CFrame.new(cf.Position,aimPos),1-F.Aim.Smooth) end
    end

    if F.Aim.Trigger and (os.clock()-lastFire)*1000>=F.Aim.TrigDelay then
        local t=Aim.getTarget(10,true); if t then lastFire=os.clock(); fireClick() end
    end

    if F.Mov.NcGlitch and isHoldingSnack() and not _ncCooldown then
        if CharacterCollision then pcall(function() CharacterCollision.Enabled=false end) end
        local h=hum()
        if h and h.MoveDirection.Magnitude>0 then _ncLastMove=tick() end
        if tick()-_ncLastMove<0.6 and tick()-_ncLastJump<0.6 then
            _ncCooldown=true
            task.spawn(function()
                local c=char()
                if c then
                    for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end
                    task.wait(1.6)
                    for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=true end end
                end
                task.wait(0.2); _ncCooldown=false
            end)
        end
    end
end)

function Hub._unload()
    attached=false
    for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    stopCarFly(); stopSpin(); stopKillaura(); stopTriggerBot(); stopAutoArrest()
    if _antiTazeOld and _antiTazeConn and _antiTazeConn.Function then
        pcall(function() hookfunction(_antiTazeConn.Function, _antiTazeOld) end)
    end
    if healthConn then pcall(function() healthConn:Disconnect() end); healthConn=nil end
    pcall(clearNoclip); pcall(ESP.destroy); pcall(stopSpectate)
    if fovCircle then pcall(function() fovCircle:Remove() end) end
    pcall(function() fullbright(false) end)
    pcall(function() cam().FieldOfView=70 end)
    pcall(function() gui:Destroy() end)
    local hh=hum(); if hh then hh.WalkSpeed=16; hh.JumpPower=50 end
    if getgenv then getgenv().syntax=nil end
end

Hub.Aim=Aim

setupAutoEscape()
if F.Auto.Keycard then startKeycard() end

warn("[syntax] v8.0 loaded — Right Shift toggles UI · T = click-TP · Combat→RAGE · TriggerBot · Killaura · AutoArrest · AntiTaze v2 · Silent Aim upgraded"
    ..(Hub._silentHook and "" or "   [note: silent aim unavailable — executor lacks hookmetamethod]"))
