-- ============================================================
-- DISASTER COMMAND SYSTEM v3.0 - Full Replication
-- ============================================================
-- Server Script: Place in ServerScriptService
-- Client Script: Place in StarterPlayerScripts
-- ============================================================

-- ============================================================
-- SERVER CONTROLLER (ServerScriptService)
-- ============================================================
local ServerController = {}
ServerController.__index = ServerController

function ServerController.new()
    local self = setmetatable({}, ServerController)
    
    -- Create remote events
    local remoteStorage = Instance.new("Folder")
    remoteStorage.Name = "DisasterCommands"
    remoteStorage.Parent = game:GetService("ReplicatedStorage")
    
    self.commandRemote = Instance.new("RemoteEvent")
    self.commandRemote.Name = "CommandEvent"
    self.commandRemote.Parent = remoteStorage
    
    self.effectRemote = Instance.new("RemoteEvent")
    self.effectRemote.Name = "EffectEvent"
    self.effectRemote.Parent = remoteStorage
    
    -- Handle commands from clients
    self.commandRemote.OnServerEvent:Connect(function(player, command, data)
        if player:GetRankInGroup(1) >= 3 then -- Admin check
            self:executeCommand(player, command, data)
        end
    end)
    
    self.activeEffects = {}
    self.pendingExplosions = {}
    
    return self
end

-- ============================================================
-- TSUNAMI COMMAND
-- ============================================================
function ServerController:executeTsunami(player, height)
    height = height or 100
    
    -- Create tsunami wave
    local wave = Instance.new("Part")
    wave.Name = "Tsunami_Wave"
    wave.Size = Vector3.new(600, height, 40)
    wave.Position = Vector3.new(0, -height/2, 350)
    wave.BrickColor = BrickColor.new("Bright blue")
    wave.Material = Enum.Material.Water
    wave.Transparency = 0.4
    wave.CanCollide = true
    wave.Anchored = false
    wave.Parent = workspace
    
    -- Water particles
    local particles = Instance.new("ParticleEmitter")
    particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particles.Rate = 500
    particles.Lifetime = NumberRange.new(3, 6)
    particles.SpreadAngle = Vector2.new(30, 30)
    particles.Size = NumberSequence.new(4, 12)
    particles.Transparency = NumberSequence.new(0, 1)
    particles.Color = ColorSequence.new(Color3.new(0.2, 0.5, 1))
    particles.Parent = wave
    
    -- Movement coroutine
    coroutine.wrap(function()
        local startPos = wave.Position
        local targetPos = Vector3.new(0, -height/2, -350)
        local duration = 6
        local elapsed = 0
        
        while elapsed < duration do
            elapsed = elapsed + 0.05
            local progress = elapsed / duration
            local eased = progress * progress * (3 - 2 * progress)
            
            -- Move wave
            wave.Position = Vector3.new(
                0,
                -height/2 + math.sin(progress * math.pi * 3) * height * 0.15,
                startPos.Z + (targetPos.Z - startPos.Z) * eased
            )
            
            -- Grow wave
            wave.Size = Vector3.new(
                600 + progress * 200,
                height * (1 + math.sin(progress * math.pi) * 0.2),
                40 + progress * 60
            )
            
            -- Push players and damage
            for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
                local char = plr.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local humanoid = char:FindFirstChild("Humanoid")
                    if hrp and humanoid then
                        local dist = (hrp.Position - wave.Position).Magnitude
                        if dist < 150 then
                            -- Push force
                            local force = (wave.CFrame.LookVector * 100 + Vector3.new(0, 40, 0)) * (1 - dist/150)
                            hrp.Velocity = hrp.Velocity + force
                            
                            -- Damage if submerged
                            if hrp.Position.Y < wave.Position.Y + wave.Size.Y/2 then
                                humanoid:TakeDamage(8)
                                
                                -- Drowning effect
                                local drownEffect = Instance.new("Part")
                                drownEffect.Size = Vector3.new(3, 3, 3)
                                drownEffect.Position = hrp.Position + Vector3.new(0, 1, 0)
                                drownEffect.BrickColor = BrickColor.new("Bright blue")
                                drownEffect.Material = Enum.Material.Water
                                drownEffect.Transparency = 0.5
                                drownEffect.Anchored = true
                                drownEffect.CanCollide = false
                                drownEffect.Parent = workspace
                                game:GetService("Debris"):AddItem(drownEffect, 0.5)
                            end
                        end
                    end
                end
            end
            
            -- Replicate to clients
            self.effectRemote:FireAllClients("tsunami_effect", {
                position = wave.Position,
                size = wave.Size,
                progress = progress
            })
            
            task.wait(0.05)
        end
        
        -- Crash effect
        for i = 1, 80 do
            local spray = Instance.new("Part")
            spray.Size = Vector3.new(2, 2, 2)
            spray.Position = wave.Position + Vector3.new(
                math.random(-250, 250),
                math.random(0, 40),
                math.random(-30, 30)
            )
            spray.BrickColor = BrickColor.new("Bright blue")
            spray.Material = Enum.Material.Water
            spray.Transparency = 0.6
            spray.Anchored = false
            spray.CanCollide = false
            spray.Velocity = Vector3.new(
                math.random(-30, 30),
                math.random(30, 80),
                math.random(-20, 20)
            )
            spray.Parent = workspace
            game:GetService("Debris"):AddItem(spray, 4)
        end
        
        wave:Destroy()
        self.effectRemote:FireAllClients("tsunami_end")
    end)()
end

-- ============================================================
-- EARTHQUAKE COMMAND
-- ============================================================
function ServerController:executeEarthquake(player, intensity)
    intensity = intensity or 8
    
    -- Create earthquake zone
    local quakeZone = Instance.new("Part")
    quakeZone.Name = "Earthquake_Zone"
    quakeZone.Size = Vector3.new(500, 50, 500)
    quakeZone.Position = Vector3.new(0, -25, 0)
    quakeZone.Anchored = true
    quakeZone.Transparency = 0.85
    quakeZone.BrickColor = BrickColor.new("Bright red")
    quakeZone.Material = Enum.Material.Neon
    quakeZone.CanCollide = false
    quakeZone.Parent = workspace
    
    -- Ground cracks
    local crackGroup = Instance.new("Model")
    crackGroup.Name = "Cracks"
    crackGroup.Parent = quakeZone
    
    for i = 1, intensity * 3 do
        local crack = Instance.new("Part")
        crack.Name = "Crack_" .. i
        crack.Size = Vector3.new(
            math.random(1, 6),
            0.3,
            math.random(8, 35)
        )
        crack.Position = Vector3.new(
            math.random(-240, 240),
            -24,
            math.random(-240, 240)
        )
        crack.CFrame = crack.CFrame * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
        crack.Anchored = true
        crack.BrickColor = BrickColor.new("Really black")
        crack.Material = Enum.Material.Slate
        crack.CanCollide = true
        crack.Parent = crackGroup
    end
    
    -- Shake coroutine
    coroutine.wrap(function()
        local duration = 10 + intensity
        local elapsed = 0
        
        while elapsed < duration do
            elapsed = elapsed + 0.1
            
            -- Shake all unanchored parts
            for _, part in ipairs(workspace:GetDescendants()) do
                if part:IsA("BasePart") and not part.Anchored and part.Parent ~= quakeZone then
                    local dist = (part.Position - quakeZone.Position).Magnitude
                    if dist < 250 then
                        local power = (1 - dist/250) * intensity * 3
                        local shake = Vector3.new(
                            math.random() * 2 - 1,
                            math.random() * 2 - 1,
                            math.random() * 2 - 1
                        ) * power
                        part.Velocity = part.Velocity + shake * 0.4
                    end
                end
            end
            
            -- Damage players
            for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
                local char = plr.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local humanoid = char:FindFirstChild("Humanoid")
                    if hrp and humanoid then
                        local dist = (hrp.Position - quakeZone.Position).Magnitude
                        if dist < 200 then
                            -- Fall damage from shaking
                            if hrp.Velocity.Y < -20 then
                                humanoid:TakeDamage(5)
                            end
                            
                            -- Random debris damage
                            if math.random() < 0.02 * (1 - dist/200) then
                                humanoid:TakeDamage(10)
                            end
                        end
                    end
                end
            end
            
            -- Replicate shake to clients
            self.effectRemote:FireAllClients("earthquake_shake", {
                intensity = intensity * (1 - elapsed/duration),
                time = elapsed
            })
            
            task.wait(0.1)
        end
        
        quakeZone:Destroy()
        self.effectRemote:FireAllClients("earthquake_end")
    end)()
end

-- ============================================================
-- EXPLOSION COMMAND - Kill All Players
-- ============================================================
function ServerController:executeExplosion(player, radius)
    radius = radius or 300
    
    -- Create massive explosion
    local explosion = Instance.new("Explosion")
    explosion.Position = Vector3.new(0, 20, 0)
    explosion.BlastRadius = radius
    explosion.BlastPressure = 150000
    explosion.ExplosionType = Enum.ExplosionType.Craters
    explosion.Parent = workspace
    
    -- Visual effects
    self.effectRemote:FireAllClients("explosion_effect", {
        position = Vector3.new(0, 20, 0),
        radius = radius
    })
    
    -- Kill all players
    for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
        local char = plr.Character
        if char then
            local humanoid = char:FindFirstChild("Humanoid")
            if humanoid then
                -- Instant kill with explosion damage
                humanoid:TakeDamage(humanoid.MaxHealth)
                
                -- Force ragdoll effect
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Velocity = Vector3.new(
                        math.random(-100, 100),
                        math.random(50, 150),
                        math.random(-100, 100)
                    )
                end
                
                -- Break all joints for ragdoll
                for _, joint in ipairs(char:GetDescendants()) do
                    if joint:IsA("Joint") or joint:IsA("Motor6D") then
                        joint:Destroy()
                    end
                end
            end
        end
    end
    
    -- Create shockwave particles
    for i = 1, 200 do
        local debris = Instance.new("Part")
        debris.Size = Vector3.new(
            math.random(1, 4),
            math.random(1, 4),
            math.random(1, 4)
        )
        debris.Position = Vector3.new(
            math.random(-radius/2, radius/2),
            math.random(0, 30),
            math.random(-radius/2, radius/2)
        )
        debris.BrickColor = BrickColor.random()
        debris.Material = Enum.Material.Granite
        debris.Anchored = false
        debris.CanCollide = true
        debris.Velocity = Vector3.new(
            math.random(-80, 80),
            math.random(50, 150),
            math.random(-80, 80)
        )
        debris.Parent = workspace
        game:GetService("Debris"):AddItem(debris, 5)
        
        -- Fire trail
        local fire = Instance.new("ParticleEmitter")
        fire.Texture = "rbxasset://textures/particles/explosion_sparkles.dds"
        fire.Rate = 50
        fire.Lifetime = NumberRange.new(0.5, 1.5)
        fire.SpreadAngle = Vector2.new(180, 180)
        fire.Size = NumberSequence.new(2, 6)
        fire.Transparency = NumberSequence.new(0, 1)
        fire.Color = ColorSequence.new(Color3.new(1, 0.5, 0), Color3.new(1, 0, 0))
        fire.Parent = debris
    end
    
    -- Nuclear mushroom cloud
    local cloud = Instance.new("Part")
    cloud.Name = "MushroomCloud"
    cloud.Size = Vector3.new(80, 100, 80)
    cloud.Position = Vector3.new(0, 60, 0)
    cloud.Shape = Enum.PartType.Cylinder
    cloud.BrickColor = BrickColor.new("Dark grey")
    cloud.Material = Enum.Material.Neon
    cloud.Transparency = 0.7
    cloud.Anchored = true
    cloud.CanCollide = false
    cloud.Parent = workspace
    
    local cloudParticles = Instance.new("ParticleEmitter")
    cloudParticles.Texture = "rbxasset://textures/particles/smoke_main.dds"
    cloudParticles.Rate = 200
    cloudParticles.Lifetime = NumberRange.new(3, 8)
    cloudParticles.SpreadAngle = Vector2.new(90, 90)
    cloudParticles.Size = NumberSequence.new(10, 30)
    cloudParticles.Transparency = NumberSequence.new(0.3, 1)
    cloudParticles.Color = ColorSequence.new(Color3.new(0.8, 0.8, 0.8), Color3.new(0.3, 0.3, 0.3))
    cloudParticles.Parent = cloud
    
    game:GetService("TweenService"):Create(cloud, TweenInfo.new(5), {
        Size = Vector3.new(150, 200, 150),
        Transparency = 0.2
    }):Play()
    
    game:GetService("Debris"):AddItem(cloud, 10)
end

-- ============================================================
-- COMMAND DISPATCHER
-- ============================================================
function ServerController:executeCommand(player, command, data)
    if command == "tsunami" then
        local height = data and data.height or 100
        self:executeTsunami(player, height)
        
    elseif command == "earthquake" then
        local intensity = data and data.intensity or 8
        self:executeEarthquake(player, intensity)
        
    elseif command == "explosion" then
        local radius = data and data.radius or 300
        self:executeExplosion(player, radius)
        
    elseif command == "kill_all" then
        -- Direct kill command without explosion
        for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
            local char = plr.Character
            if char then
                local humanoid = char:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid:TakeDamage(humanoid.MaxHealth)
                end
            end
        end
        self.effectRemote:FireAllClients("kill_effect")
    end
end

-- ============================================================
-- CLIENT CONTROLLER (LocalScript)
-- ============================================================
local ClientController = {}
ClientController.__index = ClientController

function ClientController.new()
    local self = setmetatable({}, ClientController)
    
    -- Create GUI
    self.screenGui = Instance.new("ScreenGui")
    self.screenGui.Name = "DisasterCommands"
    self.screenGui.Parent = game:GetService("Players").LocalPlayer.PlayerGui
    
    self:createUI()
    self:setupRemotes()
    self:setupEffects()
    
    return self
end

-- ============================================================
-- UI CREATION
-- ============================================================
function ClientController:createUI()
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 420)
    frame.Position = UDim2.new(0, 10, 0.5, -210)
    frame.BackgroundColor3 = Color3.new(0.05, 0.05, 0.1)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.new(0.8, 0.2, 0.2)
    frame.Parent = self.screenGui
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 50)
    title.BackgroundTransparency = 1
    title.Text = "☢ COMMAND CENTER"
    title.TextColor3 = Color3.new(1, 0.2, 0.2)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = frame
    
    -- Tsunami Button
    local tsunamiBtn = self:createButton(frame, "🌊 TSUNAMI", 60, Color3.new(0.1, 0.3, 0.9))
    tsunamiBtn.MouseButton1Click:Connect(function()
        self:sendCommand("tsunami", { height = 100 })
    end)
    
    -- Earthquake Button
    local quakeBtn = self:createButton(frame, "🌋 EARTHQUAKE", 115, Color3.new(0.9, 0.4, 0.1))
    quakeBtn.MouseButton1Click:Connect(function()
        self:sendCommand("earthquake", { intensity = 8 })
    end)
    
    -- Explosion Button (Kill All)
    local explosionBtn = self:createButton(frame, "💥 NUCLEAR EXPLOSION", 170, Color3.new(0.9, 0.1, 0.1))
    explosionBtn.MouseButton1Click:Connect(function()
        self:sendCommand("explosion", { radius = 350 })
    end)
    
    -- Kill All Button (Instant)
    local killBtn = self:createButton(frame, "☠ KILL ALL PLAYERS", 225, Color3.new(0.5, 0, 0))
    killBtn.MouseButton1Click:Connect(function()
        self:sendCommand("kill_all", {})
    end)
    
    -- Intensity Slider
    self:createSlider(frame, 280)
    
    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextScaled = true
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = frame
    
    closeBtn.MouseButton1Click:Connect(function()
        self.screenGui:Destroy()
    end)
    
    -- Admin warning
    local warning = Instance.new("TextLabel")
    warning.Size = UDim2.new(1, 0, 0, 20)
    warning.Position = UDim2.new(0, 0, 1, -20)
    warning.BackgroundTransparency = 1
    warning.Text = "⚠ ADMIN ONLY"
    warning.TextColor3 = Color3.new(1, 0.8, 0)
    warning.TextScaled = true
    warning.Font = Enum.Font.Gotham
    warning.Parent = frame
end

function ClientController:createButton(parent, text, yPos, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 45)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.Parent = parent
    return btn
end

function ClientController:createSlider(parent, yPos)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(0.9, 0, 0, 50)
    sliderFrame.Position = UDim2.new(0.05, 0, 0, yPos)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new
