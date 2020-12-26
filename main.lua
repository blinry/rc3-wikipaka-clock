love.filesystem.setIdentity("radiant-rewind")

local pathSeparator = package.config:sub(1,1)
local configFileName = "inputconfig.lua"
configFilePath = love.filesystem.getSaveDirectory() .. pathSeparator .. configFileName
require("inputconfig")
if love.filesystem.getRealDirectory(configFileName) == love.filesystem.getSaveDirectory() then
    -- This file is in the save directory.
    print("Opened custom " .. configFileName  .. " from " .. configFilePath)
    contents, size = love.filesystem.read(configFileName)
    -- if the player has an old version of the input config file, we need to patch in the new options for mute and/or effects
    if not keymapping.mute then
        keymapping.mute = {
            mouseButtons = {},
            keys = {"m"},
            joystickButtons = {}
        }
        contents = contents:gsub("reload = {", [[mute = {
        mouseButtons = {},
        keys = {"m"},
        joystickButtons = {}
    }, 
    reload = {]]);
    end
    if not keymapping.effects then
        keymapping.effects = {
            mouseButtons = {},
            keys = {"e"},
            joystickButtons = {}
        }
        contents = contents:gsub("reload = {", [[effects = {
        mouseButtons = {},
        keys = {"e"},
        joystickButtons = {}
    }, 
    reload = {]]);
    end
    
        
    love.filesystem.write(configFileName, contents)
else
    print("Creating custom " .. configFileName .. " in " .. configFilePath)
    contents, size = love.filesystem.read(configFileName)
    love.filesystem.write(configFileName, contents)
end

require "lib.slam"
vector = require "lib.hump.vector"
tlfres = require "lib.tlfres"
class = require 'lib.middleclass' -- see https://github.com/kikito/middleclass

require "helpers"
Particles = require "Particles"
local moonshine = require 'lib.moonshine'

-- global constants
CANVAS_WIDTH = 1920
CANVAS_HEIGHT = 1080

TAU = 2*math.pi

CENTER = vector(CANVAS_WIDTH/2,CANVAS_HEIGHT/2)

-- effects constants
SCREEN_SHAKE_TIMEMACHING_BEGIN = 20
SCREEN_SHAKE_TIMEMACHING_DURING = 7
GOD_RAYS_NORMAL = 0.0
GOD_RAYS_TIMEMACHINE = 0.5
GOD_RAYS_SLOMO = 0.25
GOD_RAYS_START_SCREEN = 0.3

god_rays_target = GOD_RAYS_START_SCREEN
god_rays_amount = GOD_RAYS_START_SCREEN

-- initialization for global variables

rainbowColors = {
    {1.0, 0.05, 0.3},
    {1.0, 0.4, 0.05},
    {1.0, 1.0, 0.05},
    {0.05, 1.0, 0.3},
    {0.05, 0.3, 1.0},
    {0.4, 0.05, 1.0}
}

lightGray = {0.5, 0.5, 0.5}
darkGray = {0.2, 0.2, 0.2}

bricks = {}
scene = nil
timemachine = nil
colorCombo = nil
paused = false
timetravelling = false
effectTime = 2340
effectStrength = 0.2
slomo = false
slomoSpeed = 1 -- in percent of normal speed
minSlomoSpeed = 0.2
slomoChange = 0.02
slomoFrame = 0 -- we count the frames to discard some of them in the time machine...

currentMusic = nil
currentMusicBackwards = nil

levelNumber = 1
requestLevelLoad = false
levelChanging = false
transitionTime = 0
maxTransitionTime = 1.45 -- duration of the sound effect (rocket_woosh)

screenshakeAmount = 0
time_since_cloud = 0

startScreen = true
hintOpacity = 0
timeHintOn = false
comboHintOn = false
everRewinded = false
everSlomoed = false
everComboed = false

levelSettings = {}
gameInWon = false
muted = false
effectsMuted = false

input = nil

function readAll(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

offset = tonumber(readAll("offset-in-seconds.txt"))

function love.load()
    -- set up default drawing options
    love.graphics.setBackgroundColor(0, 0, 0)

    -- load assets
    images = {}
    for i,filename in pairs(love.filesystem.getDirectoryItems("images")) do
        if filename ~= ".gitkeep" then
            images[filename:sub(1,-5)] = love.graphics.newImage("images/"..filename)
        end
    end

    sounds = {}
    for i,filename in pairs(love.filesystem.getDirectoryItems("sounds")) do
        if filename ~= ".gitkeep" then
            sounds[filename:sub(1,-5)] = love.audio.newSource("sounds/"..filename, "static")
        end
    end

    music = {}
    for i,filename in pairs(love.filesystem.getDirectoryItems("music")) do
        if filename ~= ".gitkeep" then
            music[filename:sub(1,-5)] = love.audio.newSource("music/"..filename, "stream")
            music[filename:sub(1,-5)]:setLooping(true)
            music[filename:sub(1,-5)]:setVolume(0.25)
        end
    end

    currentMusic = music.severe_tire_damage
    -- currentMusicBackwards = music.severe_tire_damage_reverse
    -- currentMusic:play()

    fonts = {}
    for i,filename in pairs(love.filesystem.getDirectoryItems("fonts")) do
        if filename ~= ".gitkeep" then
            fonts[filename:sub(1,-5)] = {}
            fonts[filename:sub(1,-5)][300] = love.graphics.newFont("fonts/"..filename, 300)
        end
    end
    mainFont = fonts.righteous
    love.graphics.setFont(mainFont[300])
    defaultFont = love.graphics.newFont(20)

    --love.mouse.setRelativeMode(true)

    -- setup effects

    --effect = moonshine(moonshine.effects.scanlines).chain(moonshine.effects.colorgradesimple).chain(moonshine.effects.crt).chain(moonshine.effects.glow)
    --effect = moonshine(moonshine.effects.scanlines).chain(moonshine.effects.colorgradesimple).chain(moonshine.effects.glow).chain(moonshine.effects.godsray)
    effect = moonshine(moonshine.effects.fastgaussianblur).chain(moonshine.effects.filmgrain).chain(moonshine.effects.scanlines).chain(moonshine.effects.chromasep)
    --effect.godsray.exposure = GOD_RAYS_NORMAL
    --effect.godsray.weight = GOD_RAYS_NORMAL
    --effect.godsray.samples = 10
    --effect.godsray.density = 0.10
    --effect.glow.min_luma = 0.7
    --effect.glow.strength = 2
    --effect.scanlines.width = 3
    --effect.scanlines.thickness = 1
    --effect.scanlines.opacity = 0.15
    --effect.colorgradesimple.factors = {2,2,2}
    effect.chromasep.angle = TAU/8
    effect.chromasep.radius = 10
    effect.fastgaussianblur.offset = 3

    levelSettings = defaultLevelSettings()
    startScreenLevelSettings()

    -- comment in the following lines to disable the effects: --
    -- effect.disable("scanlines")
    --effect.disable("colorgradesimple")
    --effect.disable("glow")
    --effect.disable("godsray")
    --effect.disable("scanlines")

    Particles:initParticlesFromSettings()

    -- handle input
    --input = Input:new()

    --initSpectrum()
end

function defaultLevelSettings() 
    return {
        name = "No Name",
        backgroundColor = {0.05, 0.0, 0.05},
        star = {
            number = 30,
            color = {1,1,1,1}
        },
        brightstar = {
            number = 30,
            color = {1,1,1,1}
        },
        radius = 350,
        clouds = { -- every cloud definition MUST have a different color per level!
            {
                color = {0.20,0.03,0.14},
                pos = vector(600,600)
            },
            {
                color = {0.07,0.03,0.10},
                pos = vector(1700,200)
            },
            {
                color = {0.02,0.05,0.12},
                pos = vector(200,100)
            }
        },
        circles = {
            color = {0.8, 0.2, 1.00},
            active = true,
            distance = 50,
            animated = true,
            alpha = 0.25,
            minRadius = 500,
            maxRadius = 2300,
        },
        lines = {
            color = {0.8, 0.2, 1.00},
            active = true,
            distance = 5,
            animated = true,
            alpha = 0.2
        }
    }
end

function startScreenLevelSettings()
    levelSettings = defaultLevelSettings()
    levelSettings.clouds = {}
    for _, col in ipairs(rainbowColors) do
        local f = 0.15
        table.insert( levelSettings.clouds, 
            {
                color = {col[1] * f, col[2] * f, col[3] * f},
                pos = vector(math.random(0,1920),math.random(0,1080))
            }
        )
    end
end

function love.update(dt)
    --updateSpectrum(dt)
    dt = dt*slomoSpeed

    --input:update(dt)
    --handleInput()
    
    time_since_cloud = time_since_cloud + dt
    effectTime = effectTime + dt * 0.3
    if time_since_cloud > 1 then
        for _, cloud in ipairs(levelSettings.clouds) do
            particles:createParticles("cloud", cloud.color, cloud.pos, 1, 0)
        end
        time_since_cloud = 0
    end

    if startScreen or not paused then
        particles:update(dt)
    end

    if not paused then
        slomoFrame = slomoFrame + 1

        if ((timeHintOn and levelNumber == 1) or (comboHintOn and levelNumber == 2)) and hintOpacity < 1 and not levelChanging then
            hintOpacity = hintOpacity + 0.01
        end
        if (not timeHintOn and levelNumber == 1) or (not comboHintOn and levelNumber == 2) and hintOpacity > 0 then
            hintOpacity = hintOpacity - 0.01
        end

        if everRewinded and everSlomoed then
            timeHintOn = false
        end

        if everComboed then
            comboHintOn = false
        end

        if slomo then
            if not timemachine:hasPast() then
                slomoOff()
            else 
                for i=1,2 do -- do it twice, or we will only remove as much frames as we add
                    timemachine:removeFirst()
                end
                if slomoSpeed > minSlomoSpeed then
                    slomoSpeed = slomoSpeed - slomoChange
                end
            end
        else
            if slomoSpeed < 1 then
                slomoSpeed = slomoSpeed + slomoChange
            end
        end

    end


    if god_rays_amount < god_rays_target then
        god_rays_amount = math.min(god_rays_target, god_rays_amount + dt)
    end
    if god_rays_amount > god_rays_target then
        god_rays_amount = math.max(god_rays_target, god_rays_amount - dt)
    end

    if god_rays_amount <= 0 then
        effect.disable("godsray")
    else
        effect.enable("godsray")
    end
    --effect.godsray.exposure = god_rays_amount
    --effect.godsray.weight = god_rays_amount
end

function love.mouse.getPosition()
    return vector(tlfres.getMousePosition(CANVAS_WIDTH, CANVAS_HEIGHT))
end

function handleInput() 
    if input:isPressed("click") and startScreen and not paused then
        requestLevelLoad = true
        god_rays_target = GOD_RAYS_NORMAL
    end

    if input:isPressed("quit") then
        love.window.setFullscreen(false)
        love.event.quit()
    elseif input:isPressed("fullscreen") then
        isFullscreen = love.window.getFullscreen()
        love.window.setFullscreen(not isFullscreen)
    end

    if input:isPressed("mute") then
        muted = not muted
        if muted then
            currentMusic:setVolume(0)
            currentMusicBackwards:setVolume(0)
        else
            currentMusic:setVolume(0.25)
            currentMusicBackwards:setVolume(0.25)
        end
    end

    if input:isPressed("effects") then
        effectsMuted = not effectsMuted
    end

    if input:isReleased("rewind") and not paused and not startScreen then
        rewindOff()
    -- TODO this should not be an elseif in case both keys are released at the same time
    elseif input:isReleased("slomo") and not paused and slomo and not startScreen then
        slomoOff()
    end
    
    if startScreen then
        -- put key bindings for start screen here:
        if input:isPressed("pause") then
            --love.mouse.setRelativeMode(paused)
            paused = not paused
        end
    else
        if levelChanging then
            return
        end
        -- put key bindings for playing screen here:
        if input:isPressed("rewind") and not paused and not startScreen then
            rewindOn()
        elseif input:isPressed("slomo") and not paused and not slomo and timemachine:hasPast() then
            slomoOn()
        elseif input:isPressed("pause") then
            --love.mouse.setRelativeMode(paused)
            paused = not paused
            if paused then
                if timetravelling then
                    currentMusicBackwards:pause()
                else 
                    currentMusic:pause()
                end
            else
                if timetravelling then
                    local pos = currentMusicBackwards:tell()
                    -- The next line is here so that SLAM only needs to handle one version of the music,
                    -- because play() spawns a new one.
                    currentMusicBackwards:stop()
                    currentMusicBackwards:play()
                    currentMusicBackwards:seek(pos)
                else
                    local pos = currentMusic:tell()
                    -- Same here.
                    currentMusic:stop()
                    currentMusic:play()
                    currentMusic:seek(pos)
                end
            end
        -- cheats: --

        -- elseif key == "a" then
            --scene:addBall()
        -- elseif key == "q" then
            --scene:resetToOneBall()
            
        elseif input:isPressed("reload") and not timetravelling then
            requestLevelLoad = true
        elseif input:isPressed("powerup") then
            colorCombo:triggerEffect()
        end
    end
end

-- special handling for level shortcuts, this does not translate well to the new input system
function love.keypressed(key, scancode, isrepeat)
end

function rewindOn()
    if levelChanging then
        return
    end
    if slomo then
        slomoOff()
    end
    everRewinded = true
    timetravelling = true
    if currentMusic ~= nil and currentMusic:isPlaying() then
        local musicPosition = math.max(0, currentMusic:getDuration() - (currentMusic:tell() or 0))
        print("rewindOn. Normal pos " .. (currentMusic:tell() or 0) .. ", backwards position " .. musicPosition .. " of " .. currentMusic:getDuration() )
        currentMusic:stop()
        currentMusicBackwards:setPitch(2)
        currentMusicBackwards:play()
        currentMusicBackwards:seek(musicPosition)
    end
    screenshakeAmount = SCREEN_SHAKE_TIMEMACHING_BEGIN
    colorCombo:reset()
    god_rays_target = GOD_RAYS_TIMEMACHINE
end

function rewindOff()
    if levelChanging then
        return
    end
    timetravelling = false

    local musicPosition = math.max(0, currentMusicBackwards:getDuration() - (currentMusicBackwards:tell() or 0))
    print("rewindOff. Backward pos " .. (currentMusicBackwards:tell() or 0) .. ", normal position " .. musicPosition)
    currentMusicBackwards:stop()
    currentMusic:play()
    currentMusic:seek(musicPosition)

    god_rays_target = GOD_RAYS_NORMAL

    if input:isDown("slomo") then
        slomoOn()
    end
end

function slomoOn()
    if timetravelling or levelChanging then
        return
    end

    everSlomoed = true
    sounds.blub_reverse:play()
    slomo = true
    god_rays_target = GOD_RAYS_SLOMO

    if currentMusic:isPlaying() then
        local pos = currentMusic:tell() or 0
        currentMusic:stop()
        currentMusic:setPitch(0.5)
        currentMusic:play()
        currentMusic:seek(pos)
    end
end

function slomoOff()
    sounds.blub:play()
    slomo = false
    god_rays_target = GOD_RAYS_NORMAL

    if currentMusic:isPlaying() then
        local pos = currentMusic:tell() or 0
        currentMusic:stop()
        currentMusic:setPitch(1)
        currentMusic:play()
        currentMusic:seek(pos)
    end
end

function love.draw()
    love.graphics.setBackgroundColor(levelSettings.backgroundColor)

    effect(function()
        tlfres.beginRendering(CANVAS_WIDTH, CANVAS_HEIGHT)

        love.graphics.setBlendMode("add")
        particles:draw(true)
        love.graphics.setBlendMode("alpha")

        clock()

        tlfres.endRendering()
    end)
end

function clock()
    love.graphics.setColor(colorCycle(slomoFrame/10))

    r1 = 300
    r2 = r1*0.8

    real_time = os.time()
    fixed_time = real_time + offset

    h = os.date("%H", fixed_time)
    m = os.date("%M", fixed_time)
    s = os.date("%S", fixed_time)

    yo = -CANVAS_HEIGHT*0.15

    love.graphics.setLineWidth(15)
    love.graphics.circle("fill", CENTER.x, CENTER.y+yo, 30)


    for i=0,11 do
        a = i/12*TAU
        love.graphics.line(CENTER.x+math.sin(a)*r1, CENTER.y+math.cos(a)*r1+yo, CENTER.x+math.sin(a)*r2, CENTER.y+math.cos(a)*r2+yo)
    end

    love.graphics.setLineWidth(25)

    -- hour handle
    r2 = r1*0.5
    a = ((h+m/60+s/(60*60))%12)/12*TAU - TAU/4
    love.graphics.line(CENTER.x, CENTER.y+yo, CENTER.x+math.cos(a)*r2, CENTER.y+math.sin(a)*r2+yo)

    -- minute handle
    r2 = r1*0.75
    a = m/60*TAU - TAU/4
    love.graphics.line(CENTER.x, CENTER.y+yo, CENTER.x+math.cos(a)*r2, CENTER.y+math.sin(a)*r2+yo)

    -- seconds handle
    love.graphics.setLineWidth(10)
    r2 = r1
    a = s/60*TAU - TAU/4
    love.graphics.line(CENTER.x, CENTER.y+yo, CENTER.x+math.cos(a)*r2, CENTER.y+math.sin(a)*r2+yo)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("WTF", 0, CANVAS_HEIGHT*0.62, CANVAS_WIDTH, "center")
end

function love.resize(w, h)
    effect.resize(w, h)
end

function colorCycle(i)
    local speed = 0.05

    return {
        0.5+0.5*math.cos(i*speed + 0),
        0.5+0.5*math.cos(i*speed + TAU/3),
        0.5+0.5*math.cos(i*speed + TAU*2/3),
    }
end

function drawBackgroundLines() 
    love.graphics.setLineWidth(1 + 1.5 * effectStrength * effectStrength * effectStrength)
    for rl = levelSettings.circles.minRadius,levelSettings.circles.maxRadius,levelSettings.circles.distance do
        local r = rl + effectStrength * 8
        local rt = rl + effectStrength * 1.5
        local t = (rt - levelSettings.circles.minRadius) / (levelSettings.circles.maxRadius - levelSettings.circles.minRadius)
        local a = levelSettings.circles.alpha  * effectStrength
        if levelSettings.circles.animated then
            a = (-0.1 + math.sin(effectTime * (2+t) * 0.3) * levelSettings.circles.alpha) * effectStrength
        end
        if levelSettings.circles.active then
            local c = levelSettings.circles.color
            love.graphics.setColor(c[1], c[2], c[3], a)
            love.graphics.circle("line", CENTER.x, CENTER.y, r)
        end
        if levelSettings.lines.active then
            a = levelSettings.lines.alpha * effectStrength
            if levelSettings.lines.animated then
                a = -0.1 + math.sin(effectTime * (2+t) * 0.3) * 0.25 * effectStrength
            end
            local c = levelSettings.lines.color
            love.graphics.setColor(c[1], c[2], c[3], a + 0.2 * effectStrength)
            for deg = 0, 359, levelSettings.lines.distance do
                local ang = deg / 360 * TAU
                love.graphics.line(CENTER.x + math.sin(ang) * (r - 25), CENTER.y + math.cos(ang) * (r - 25), CENTER.x + math.sin(ang) * (r + 25), CENTER.y + math.cos(ang) * (r + 25))
            end
        end
    end

    love.graphics.setLineWidth(2)
end
