-- Game configuration and constants
local config = {}

config.FONT_PATH = "assets/fonts/LXGWWenKaiLite-Regular.ttf"

config.BACKGROUND = {
    image = "cardtable.png",
    color = { 0.08, 0.09, 0.12 },
    overlay = { 0.04, 0.05, 0.09, 0.45 },
}

config.CARD = {
    width = 96,
    height = 136,
}

-- Card outline configuration
config.CARD_OUTLINE = {
    enabled = true,          -- Enable outline
    width = 2,               -- Outline width (pixels)
    color = { 0, 0, 0, 0.6 }, -- Outline color (RGBA, dark border to increase contrast)
    radius = 12,             -- Corner radius (smoother rounded corners)
}

-- Card corner configuration (centralized)
config.CARD_CORNER_RADIUS = 12 -- Card corner radius (pixels), used for all card rendering

config.CARD_SHADOW = {
    enabled = true,
    offsetX = 5,
    offsetY = 7,
    scale = 0.98,
    color = { 0.05, 0.06, 0.09, 0.23 },
}

config.DEAL_ANIMATION = {
    opponentInterval = 0.18,
}

-- Card image asset configuration
config.ASSETS = {
    -- Mode 1: use a shared card front/back image (recommended, simple)
    -- Path to the front image (used for all card fronts)
    CARD_FRONT_IMAGE = "assets/cards/card_front.png",
    -- Path to the back image (used for all card backs)
    CARD_BACK_IMAGE = "assets/cards/card_back.png",

    -- Mode 2: use individual images (each card has its own image)
    -- Set to true to use individual images, false to use shared images
    USE_INDIVIDUAL_CARDS = true,
    -- Individual image path pattern: {suit} is replaced with spades/hearts/clubs/diamonds,
    -- {rank} is replaced with 2-10/J/Q/K/A
    CARD_IMAGE_PATTERN = "assets/cards/{suit}_{rank}.png",
    -- Use new naming format: {rank}_of_{suit}.png (e.g. 2_of_clubs.png, ace_of_spades.png)
    USE_NEW_CARD_NAMING = true,
    CARD_IMAGE_DIR = "assets/cards/Playing Cards/Playing Cards/PNG-cards-1.3",
    -- Joker images (new format)
    JOKER_SMALL_IMAGE = "assets/cards/Playing Cards/Playing Cards/PNG-cards-1.3/black_joker.png",
    JOKER_BIG_IMAGE = "assets/cards/Playing Cards/Playing Cards/PNG-cards-1.3/red_joker.png",
    -- Card back image for individual mode. If the asset pack has no back image,
    -- you can provide a generic back image here.
    CARD_BACK_IMAGE_INDIVIDUAL = "assets/cards/playing cards/Playing Cards/PNG-cards-1.3/must_logo.png",
}

config.GAME = {
    maxValue = 10.5,
    maxBankerCards = 8,
}

config.TUTORIAL_MESSAGES = {
    "Welcome to Ten and a Half: try to get as close to 10.5 points as possible without going over.",
    "A, 2, 3, 4, 5, 6, 7, 8, 9, 10, J, Q, K, big joker, small joker correspond to 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 0.5, 0.5, 0.5.",
    "Only the banker can see their own cards; the idle player cannot see the banker’s hand.",
    "The banker first draws 1–4 cards and keeps them face down; the idle player clicks \"Hit\" to draw cards and can choose \"Stand\" at any time.",
    "If both players’ hands are below 10.5 points, the player with the higher value wins.",
    "If either player’s hand exceeds 10.5 points, they bust and the other side wins.",
    "If both players’ hands have the same value, the banker wins.",
    "If the idle player’s hand is exactly 10.5 and the banker’s is not, the idle player wins and the banker loses 3 life points.",
    "When either player busts, the other loses 1 life point; the first to reduce the opponent’s life to 0 wins the match.",
    "Use [←]/[→] to switch help pages, press [Esc] or click close to return to the game.",
}

-- Shader effect configuration
config.SHADERS = {
    -- Whether shader effects are enabled
    ENABLED = true,
    -- Card glow effect
    GLOW = {
        enabled = true,
        intensity = 0.05,
        radius = 50.0,
        color = { 1.0, 0.8, 0.2 }, -- Gold color
    },
    -- Card aura effect
    AURA = {
        enabled = true,
        intensity = 0.03,
        speed = 2.0,
        color1 = { 1.0, 0.5, 0.8 }, -- Pink-purple
        color2 = { 0.5, 0.8, 1.0 }, -- Blue-purple
    },
    -- Card sparkle particle effect
    SPARKLE = {
        enabled = true,
        intensity = 0.05,
        speed = 3.0,
        count = 3,
    },
}

-- Mouse hover visual effect (non-shader)
config.HOVER_EFFECT = {
    enabled = true,
    scale = 1.06,        -- Scale factor when hovered
    extraLift = 6,       -- Extra lift in pixels when rendering (hover feel)
    layoutLift = 18,     -- Extra lift in layout (original was 28)
    outlinePadding = 4,  -- Outline padding
    outlineColor = { 1.0, 0.9, 0.5, 0.35 },
    outlineWidth = 2,
    wobbleAmplitude = 2,          -- Vertical wobble in pixels
    wobbleSpeed = 2.2,            -- Vertical wobble speed
    wobbleHorizontalAmplitude = 1.4, -- Horizontal wobble in pixels
    wobbleHorizontalSpeed = 1.7,     -- Horizontal wobble speed
    idleWobbleAmplitude = 1.2,    -- Default vertical wobble amplitude for idle cards
    idleWobbleSpeed = 1.35,       -- Default wobble speed (restored value)
    idleWobbleHorizontalAmplitude = 0.9, -- Default horizontal wobble amplitude
    idleWobbleHorizontalSpeed = 1.1,     -- Default horizontal wobble speed (restored value)
    applyToPlayerHand = true,
    applyToOpponentHand = true,
    allowHoverGlowOpponent = true, -- Whether to apply glow shader when hovering opponent’s cards
}

config.AI_BEHAVIOR = {
    dealer = {
        forceHitBelow = 6.4,
        forceStopAbove = 9.55,
        randomHitChance = 0.45,
        safeHitAggression = 0.9,
        stopAggression = 0.7,
        chanceAggression = 0.35,
    },
    idle = {
        forceHitBelow = 7.4,
        forceStopAbove = 9.78,
        randomHitChance = 0.4,
        safeHitAggression = 0.75,
        stopAggression = 0.75,
        chanceAggression = 0.28,
    },
    pressure = {
        lifeWeight = 0.03,
        matchWeight = 0.08,
        cardCountWeight = 0.12,
        cardCountReference = 2.6,
        idleAvgWeight = 0.05,
        idleAvgReference = 3.1,
        clamp = 0.4,
    },
    mood = {
        roundRange = 0.2,
        confidenceStep = 0.07,
        confidenceClamp = 0.25,
    },
}

config.ROLE_DRAW = {
    offsetY = 70,
}

config.ZONE_STYLE = {
    showHandZones = false,      -- Control visibility of player/opponent hand zones
    showHandZoneOutline = false,
}

return config




