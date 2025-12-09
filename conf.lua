function love.conf(t)
    t.identity = "little_card_game"
    t.version = "11.5"
    -- Enable console window to see debug output.
    t.console = true

    -- Window settings
    t.window.width = 1280
    t.window.height = 720
    t.window.title = "Little Card Game Prototype"
    -- Vertical sync (1 = enabled, reduces tearing)
    t.window.vsync = 1
    t.window.resizable = true
    t.window.minwidth = 960
    t.window.minheight = 540

    -- GPU / graphics settings (improve render quality)
    t.window.msaa = 4      -- 4x MSAA anti-aliasing
    t.window.highdpi = true -- High DPI display support

    -- Module settings (enable all graphics-related modules)
    t.modules.graphics = true  -- Graphics rendering (required)
    t.modules.window = true    -- Window management (required)
    t.modules.timer = true     -- Timer (for animations)
    t.modules.mouse = true     -- Mouse input
    t.modules.keyboard = true  -- Keyboard input
    t.modules.image = true     -- Image loading
    t.modules.font = true      -- Font rendering
end

