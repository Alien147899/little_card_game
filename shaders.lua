-- Shader effect manager: load and manage game shaders
local shaders = {}
local config = require("config")

shaders.shaderObjects = {}
shaders.enabled = true

-- Menu background animation shader
local menuBackgroundShaderCode = [[
    extern float time;
    
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        // Simple color gradient + breathing effect
        float pulse = sin(time) * 0.5 + 0.5;
        
        // Base color: dark blue-purple
        vec3 baseColor = vec3(0.08 + pulse * 0.05, 0.06, 0.12 + pulse * 0.08);
        
        // Add gradient based on vertical position
        float gradient = texture_coords.y;
        baseColor = mix(baseColor, baseColor * 1.3, gradient);
        
        return vec4(baseColor, 1.0) * color;
    }
]]

-- Card glow effect shader
local cardGlowShaderCode = [[
    extern vec2 mousePos;
    extern float glowIntensity;
    extern float glowRadius;
    extern vec3 glowColor;
    
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, texture_coords) * color;
        
        // Distance from mouse cursor to current pixel
        float dist = distance(screen_coords, mousePos);
        
        // Glow strength (only on edges; does not affect center area)
        float glow = 1.0 - smoothstep(glowRadius * 0.5, glowRadius, dist);
        glow = pow(glow, 4.0) * glowIntensity * 0.3;  // Strongly reduced intensity, concentrated near the edges
        
        // Apply glow effect (light additive blend, do not overwrite original)
        vec3 finalColor = pixel.rgb + glowColor * glow;
        
        return vec4(finalColor, pixel.a);
    }
]]

-- Card hover animation shader (scale and rotation) - placeholder, currently just passes color
local cardHoverShaderCode = [[
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, texture_coords);
        return pixel * color;
    }
]]

-- Card flip animation shader - placeholder, currently just passes color
local cardFlipShaderCode = [[
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, texture_coords);
        return pixel * color;
    }
]]

-- Card aura glow effect shader
local cardAuraShaderCode = [[
    extern float auraIntensity;
    extern float auraSpeed;
    extern float time;
    extern vec3 auraColor1;
    extern vec3 auraColor2;
    
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, texture_coords) * color;
        
        // Distance from center to the edge
        vec2 center = vec2(0.5, 0.5);
        float dist = distance(texture_coords, center);
        
        // Create a pulsing aura effect (only near the edge, not the center)
        float pulse = sin(time * auraSpeed) * 0.5 + 0.5;
        float edgeDist = 1.0 - dist;
        float aura = smoothstep(0.8, 1.0, edgeDist) * auraIntensity * pulse * 0.2;  // Only in the outer 0.2 range; heavily lowered intensity
        
        // Mix two aura colors
        vec3 finalAura = mix(auraColor1, auraColor2, pulse);
        
        // Apply aura (light additive blend, do not overwrite original)
        vec3 finalColor = pixel.rgb + finalAura * aura;
        
        return vec4(finalColor, pixel.a);
    }
]]

-- Card back reflection shader
local cardBackStableShaderCode = [[
    extern vec2 textureSize;
    extern float time;
    extern vec2 tilt;  // "Tilt" direction calculated on the Lua side from card wobble, roughly in [-1, 1]
    
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        // Lightweight 2x2 bilinear sampling
        vec2 pixelSize = 1.0 / textureSize;
        vec4 s1 = Texel(texture, texture_coords);
        vec4 s2 = Texel(texture, texture_coords + vec2(pixelSize.x * 0.5, 0.0));
        vec4 s3 = Texel(texture, texture_coords + vec2(0.0, pixelSize.y * 0.5));
        vec4 s4 = Texel(texture, texture_coords + pixelSize * 0.5);
        vec4 sample = (s1 + s2 + s3 + s4) * 0.25;
        
        vec2 centerCoord = texture_coords - vec2(0.5, 0.5);
        
        // 1. Diagonal scanning highlight (more visible)
        float diagonalGradient = (texture_coords.x + texture_coords.y) * 0.5;
        float movingLight = sin(time * 1.2 + diagonalGradient * 6.28318) * 0.5 + 0.5;
        movingLight = pow(movingLight, 3.0);  // Make the light band sharper
        
        // 2. Edge highlight (Fresnel-like effect, slightly amplified)
        float distFromCenter = length(centerCoord);
        float edgeHighlight = smoothstep(0.25, 0.55, distFromCenter) * 0.12;
        
        // 3. Specular highlight (gradient from center to edge)
        float specular = 1.0 - distFromCenter * 1.5;
        specular = max(0.0, specular);
        specular = pow(specular, 2.0) * 0.10;
        
        // 4. Dynamic light spot (breathing effect)
        float pulse = sin(time * 2.0) * 0.5 + 0.5;
        float spotlight = exp(-distFromCenter * 3.0) * pulse * 0.12;
        
        // Combine all reflection components
        // When time == 0 (static deck), keep only a base reflection with much lower intensity
        float baseFactor = (time == 0.0) ? 0.3 : 1.0;  // Deck reflection reduced to 30%
        float shine = (movingLight * 0.18 + edgeHighlight + specular + spotlight) * baseFactor;
        
        // Adjust overall brightness based on card "tilt" so reflection changes with wobble (only for dynamic cards)
        if (time != 0.0) {
            // Construct an approximate normal: larger tilt means the card leans more in that direction
            vec3 normal = normalize(vec3(-tilt.x, -tilt.y, 1.0));
            vec3 lightDir = normalize(vec3(-0.4, -0.8, 1.0));   // Fixed light direction: top-left
            float lambert = clamp(dot(normal, lightDir), 0.0, 1.0);
            // Adjust reflection strength between ~0.5 and 1.1 (small change most of the time, subtly following wobble)
            float lightScale = 0.5 + lambert * 0.6;
            shine *= lightScale;
        }
        
        // Golden reflection color
        vec3 shineColor = vec3(1.0, 0.95, 0.8);  // Warm highlight tone
        
        // Add reflection to the base sample
        vec3 finalColor = sample.rgb + shineColor * shine;
        
        return vec4(finalColor, sample.a) * color;
    }
]]

-- Card particle shader (sparkling stars)
local cardSparkleShaderCode = [[
    extern float sparkleIntensity;
    extern float sparkleSpeed;
    extern float time;
    extern int sparkleCount;
    
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, texture_coords) * color;
        
        float sparkle = 0.0;
        for (int i = 0; i < 20; i++) {
            if (i >= sparkleCount) break;
            
            // Generate pseudo-random positions
            float seed = float(i) * 0.1;
            vec2 sparklePos = vec2(
                fract(sin(seed * 12.9898) * 43758.5453),
                fract(cos(seed * 78.233) * 43758.5453)
            );
            
            // Distance from sparkle center
            float dist = distance(texture_coords, sparklePos);
            
            // Create flickering effect
            float sparkleTime = time * sparkleSpeed + seed * 3.14159;
            float brightness = sin(sparkleTime) * 0.5 + 0.5;
            float sparkleSize = 0.05;
            
            sparkle += brightness * exp(-dist * dist / (sparkleSize * sparkleSize));
        }
        
        sparkle = sparkle * sparkleIntensity / float(sparkleCount) * 0.3;  // Strongly reduced particle intensity
        // Light additive blend, do not overwrite the original
        vec3 finalColor = pixel.rgb + vec3(1.0, 1.0, 1.0) * sparkle;
        
        return vec4(finalColor, pixel.a);
    }
]]

function shaders.loadShaders()
    print("[Shaders] Starting shader loading...")
    
    -- Load shaders
    local success, glowShader = pcall(function()
        return love.graphics.newShader(cardGlowShaderCode)
    end)
    if success then
        shaders.shaderObjects.glow = glowShader
        print("[Shaders] Glow shader loaded")
    else
        print("[Shaders] Glow shader failed: " .. tostring(glowShader))
    end
    
    local success, hoverShader = pcall(function()
        return love.graphics.newShader(cardHoverShaderCode)
    end)
    if success then
        shaders.shaderObjects.hover = hoverShader
    end
    
    local success, flipShader = pcall(function()
        return love.graphics.newShader(cardFlipShaderCode)
    end)
    if success then
        shaders.shaderObjects.flip = flipShader
    end
    
    local success, auraShader = pcall(function()
        return love.graphics.newShader(cardAuraShaderCode)
    end)
    if success then
        shaders.shaderObjects.aura = auraShader
    end
    
    local success, sparkleShader = pcall(function()
        return love.graphics.newShader(cardSparkleShaderCode)
    end)
    if success then
        shaders.shaderObjects.sparkle = sparkleShader
    end
    
    -- Load card-back specific shader
    local success, backStableShader = pcall(function()
        return love.graphics.newShader(cardBackStableShaderCode)
    end)
    if success then
        shaders.shaderObjects.cardBackStable = backStableShader
    end
    
    -- Load menu background animation shader
    print("[Shaders] Attempting to load menu background shader...")
    local successMenu, menuBgShader = pcall(function()
        return love.graphics.newShader(menuBackgroundShaderCode)
    end)
    print("[Shaders] Menu shader pcall result - success:", successMenu, "shader:", menuBgShader)
    if successMenu then
        shaders.shaderObjects.menuBackground = menuBgShader
        print("[Shaders] Menu background shader loaded successfully!")
    else
        print("[Shaders] Menu background shader FAILED: " .. tostring(menuBgShader))
    end
    
    print("[Shaders] Total shaders loaded:")
    for name, shader in pairs(shaders.shaderObjects) do
        print("  - " .. name .. ": " .. tostring(shader))
    end
end

function shaders.applyGlowEffect(card, game, mouseX, mouseY)
    if not shaders.enabled or not shaders.shaderObjects.glow then
        return false
    end
    
    local config = require("config")
    local shader = shaders.shaderObjects.glow
    shader:send("mousePos", {mouseX, mouseY})
    shader:send("glowIntensity", config.SHADERS.GLOW.intensity)
    shader:send("glowRadius", config.SHADERS.GLOW.radius)
    shader:send("glowColor", config.SHADERS.GLOW.color)
    
    love.graphics.setShader(shader)
    return true
end

function shaders.applyHoverEffect(card, hoverScale, hoverRotation, hoverTime)
    if not shaders.enabled or not shaders.shaderObjects.hover then
        return false
    end
    
    local shader = shaders.shaderObjects.hover
    -- Current shader does not need parameters; placeholder hook
    love.graphics.setShader(shader)
    return true
end

function shaders.applyFlipEffect(card, flipProgress, isFlipping)
    if not shaders.enabled or not shaders.shaderObjects.flip then
        return false
    end
    
    local shader = shaders.shaderObjects.flip
    -- Current shader does not need parameters; placeholder hook
    love.graphics.setShader(shader)
    return true
end

function shaders.applyAuraEffect(card, time, intensity, speed, color1, color2)
    if not shaders.enabled or not shaders.shaderObjects.aura then
        return false
    end
    
    local config = require("config")
    local shader = shaders.shaderObjects.aura
    shader:send("auraIntensity", intensity or config.SHADERS.AURA.intensity)
    shader:send("auraSpeed", speed or config.SHADERS.AURA.speed)
    shader:send("time", time or 0.0)
    shader:send("auraColor1", color1 or config.SHADERS.AURA.color1)
    shader:send("auraColor2", color2 or config.SHADERS.AURA.color2)
    
    love.graphics.setShader(shader)
    return true
end

function shaders.applySparkleEffect(card, time, intensity, speed, count)
    if not shaders.enabled or not shaders.shaderObjects.sparkle then
        return false
    end
    
    local config = require("config")
    local shader = shaders.shaderObjects.sparkle
    shader:send("sparkleIntensity", intensity or config.SHADERS.SPARKLE.intensity)
    shader:send("sparkleSpeed", speed or config.SHADERS.SPARKLE.speed)
    shader:send("time", time or 0.0)
    shader:send("sparkleCount", count or config.SHADERS.SPARKLE.count)
    
    love.graphics.setShader(shader)
    return true
end

function shaders.applyCardBackStable(textureWidth, textureHeight, time, tiltX, tiltY)
    if not shaders.enabled or not shaders.shaderObjects.cardBackStable then
        return false
    end
    
    local shader = shaders.shaderObjects.cardBackStable
    shader:send("textureSize", {textureWidth, textureHeight})
    shader:send("time", time or love.timer.getTime())
    shader:send("tilt", {tiltX or 0.0, tiltY or 0.0})
    
    love.graphics.setShader(shader)
    return true
end

function shaders.resetShader()
    love.graphics.setShader()
end

function shaders.setEnabled(enabled)
    shaders.enabled = enabled
end

-- Apply menu background animation shader
function shaders.applyMenuBackground(time, width, height)
    if not shaders.enabled or not shaders.shaderObjects.menuBackground then
        print("[Shaders] Menu background not available - enabled:", shaders.enabled, "shader:", shaders.shaderObjects.menuBackground)
        return false
    end
    
    local shader = shaders.shaderObjects.menuBackground
    shader:send("time", time or 0.0)
    
    love.graphics.setShader(shader)
    return true
end

return shaders





