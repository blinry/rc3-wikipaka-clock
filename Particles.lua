local Particles = class("Particles")

function Particles:initialize()
    self.systems = {}
end

function Particles:initParticlesFromSettings()

    particles = Particles:new()

    if levelSettings.star.number > 0 then
        particles:createParticles("star", levelSettings.star.color, CENTER, levelSettings.star.number, 0)
    end
    if levelSettings.brightstar.number > 0 then
        particles:createParticles("brightstar", levelSettings.brightstar.color, CENTER, levelSettings.brightstar.number, 0)
    end
end

function Particles:createParticles(type, color, pos, count, angle, speedMultiplier)
    -- local key = {type=type, color=color}
    local keystring = type .. "-" .. color[1] .. "-" .. color[2] .. "-" .. color[3]
    local value = self.systems[keystring]
    if value == nil then
        value = { 
            color = color,
            type = type,
            system = self:createSystem(type, color)
        }
        self.systems[keystring] = value
    end

    local system = value.system

    system:setDirection(angle, angle)
    if type == "touch" then
        system:setRotation(0, 0)
    else
        system:setRotation(angle, angle)
    end
    system:start()
    system:setPosition(pos.x, pos.y)

    local oldMinSpeed, oldMaxSpeed = system:getSpeed()
    if speedMultiplier then
        system:setSpeed(oldMinSpeed * speedMultiplier, oldMaxSpeed * speedMultiplier)
    end

    if type == "star" then
        system:setEmissionRate(3)
        system:setEmitterLifetime(3600)
    elseif type == "brightstar" then
        system:setEmissionRate(0.1)
        system:setEmitterLifetime(3600)
    else
        system:setEmissionRate(count * 100)
        system:setEmitterLifetime(0.01)
        system:update(0.01)
    end

    if speedMultiplier then
        system:setSpeed(oldMinSpeed, oldMaxSpeed)
    end
end

function Particles:update(dt)
    for key, value in pairs(self.systems) do
        if value.type == "dust" then
            value.system:update(dt * (0.33 + effectStrength * effectStrength * effectStrength * 9))
        elseif value.type == "cloud" then
        value.system:update(dt * (0.3 + effectStrength * effectStrength * 4))
        else
          value.system:update(dt)
        end
    end
end

function Particles:draw(background)
    for key, value in pairs(self.systems) do
        local type = value.type
        local system = value.system
        if background then
            if type == "star" or type == "brightstar" or type == "cloud" then
                love.graphics.draw(system, 0,0 )
            end
        else 
            if type == "touch" or type == "destroy" or type == "dust" then
                love.graphics.draw(system, 0,0 )
            end
        end
    end
end

function Particles:createSystem(type, c)
    local system = love.graphics.newParticleSystem(images.child, 200)
    system:stop()
    if type == "touch" then
        system:setTexture(images.funke1)
        system:setColors(c[1],c[2],c[3],1,c[1],c[2],c[3],0)

        system:setRotation(-math.pi, -math.pi)
        system:setEmissionArea("none", 0, 0, 0, true)
        system:setSpread(math.pi)
        system:setSpeed( 500, 1000 )
        system:setParticleLifetime(0.1, 0.35)
        system:setRelativeRotation(true)
        system:setSizes(1,1,1,0)
        system:setSpin(0,0)
    end
    if type == "destroy" then
        system:setTexture(images.funke4)
        system:setColors(
            c[1]*3+0.5,c[2]*3+0.5,c[3]*3+0.5,1,
            c[1]      ,c[2]      ,c[3]      ,1,
            c[1]      ,c[2]      ,c[3]      ,1,
            c[1]      ,c[2]      ,c[3]      ,0
        )
        system:setSpeed( 100, 500 )
        system:setSpread(TAU)
        system:setEmissionArea("normal", 15, 15, 0, true)
        system:setParticleLifetime(0.3, 1.2)
        system:setSizes(0.4)
        system:setRelativeRotation(false)
        system:setSpin(-8, 8)
    end
    if type == "star" then
        system:setTexture(images.star1)
        system:setColors(
            c[1],c[2],c[3],1
        )
        system:setSpeed( 0, 5 )
        system:setSpread(TAU)
        system:setEmissionArea("uniform", CENTER.x,  CENTER.y, 0, true)
        system:setParticleLifetime(10, 80)
        system:setSizes(0.6, 1.0)
        system:setRelativeRotation(false)
        system:setSpin(0, 0)

        system:setPosition(CENTER.x, CENTER.y)
        system:setEmissionRate(1000)
        system:setEmitterLifetime(1)
        system:start()
        system:update(1)
        system:setEmitterLifetime(3600)
        system:setEmissionRate(1)
        system:update(200)
    end
    if type == "brightstar" then
        system:setTexture(images.star2)
        system:setColors(
            c[1],c[2],c[3],0,
            c[1],c[2],c[3],1,
            c[1],c[2],c[3],1,
            c[1],c[2],c[3],1,
            c[1],c[2],c[3],0
        )
        system:setSpeed( 0, 5 )
        system:setSpread(TAU)
        system:setEmissionArea("uniform", CENTER.x,  CENTER.y, 0, true)
        system:setParticleLifetime(10, 80)
        system:setSizes(0.8, 1.8)
        system:setRelativeRotation(false)
        system:setSpin(0, 0)

        system:setPosition(CENTER.x, CENTER.y)
        system:setEmissionRate(1000)
        system:setEmitterLifetime(1)
        system:start()
        system:update(1)
        system:setEmitterLifetime(3600)
        system:setEmissionRate(0.1)
        system:update(200)
    end
    if type == "dust" then
        system:setTexture(images.star1)
        system:setColors(
            c[1],c[2],c[3],1,
            c[1],c[2],c[3],0.7,
            c[1],c[2],c[3],0
        )
        system:setSpeed( 20, 150 )
        system:setSpread(TAU)
        system:setEmissionArea("normal", 50, 50, 0, true)
        system:setParticleLifetime(2, 5)
        system:setSizes(0.5, 1.5)
        system:setLinearDamping(0.85, 0.85)
        system:setRelativeRotation(false)
        system:setSpin(0, 0)
    end
    if type == "cloud" then
        system:setTexture(images.cloud1)
        system:setColors(
            c[1],c[2],c[3],0,
            c[1],c[2],c[3],1,
            c[1],c[2],c[3],1,
            c[1],c[2],c[3],1,
            c[1],c[2],c[3],0
        )
        system:setSpeed( 0, 18 )
        system:setSpread(TAU)
        system:setEmissionArea("normal", 200,  200, 0, true)
        system:setParticleLifetime(5, 30)
        system:setSizes(0.5, 1.2)
        system:setRelativeRotation(false)
        system:setSpin(-0.3, 0.3)
        system:setBufferSize(20)
    end
    return system
end

return Particles
