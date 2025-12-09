-- Audio manager: responsible for loading and managing game audio (music and sound effects).
local audio_manager = {}

-- Audio resource storage
audio_manager.music = {}      -- Background music sources
audio_manager.sounds = {}     -- Sound effect sources

-- Volume settings
audio_manager.volumes = {
    master = 1.0,   -- Master volume (0.0 ~ 1.0)
    music = 0.7,    -- Music volume (0.0 ~ 1.0)
    sound = 0.8,    -- Sound volume (0.0 ~ 1.0)
}

-- Currently playing music
audio_manager.currentMusic = nil
audio_manager.currentMusicName = nil

-- Audio configuration
audio_manager.config = {
    -- File path configuration
    musicDir = "assets/music",
    soundDir = "assets/sounds",

    -- Music list
    musicFiles = {
        menu = "menu.ogg",         -- Menu music
        gameplay = "gameplay.ogg", -- Gameplay music
        victory = "victory.ogg",   -- Victory music
        defeat = "defeat.ogg",     -- Defeat music
    },

    -- Sound effect list
    soundFiles = {
        card_flip = "card_flip.ogg",       -- Card flip
        card_place = "card_place.ogg",     -- Card place
        card_shuffle = "card_shuffle.ogg", -- Card shuffle
        button_click = "button_click.ogg", -- Button click
        win = "win.ogg",                   -- Win sound
        lose = "lose.ogg",                 -- Lose sound
        notification = "notification.ogg", -- Notification
        error = "error.ogg",               -- Error sound
    },
}

-- Initialize audio system
function audio_manager.init()
    print("Audio system initializing...")
    audio_manager.loadMusic()
    audio_manager.loadSounds()
    print("Audio system initialized.")
end

-- Load all background music
function audio_manager.loadMusic()
    local musicDir = audio_manager.config.musicDir

    for name, filename in pairs(audio_manager.config.musicFiles) do
        local path = musicDir .. "/" .. filename
        if love.filesystem.getInfo(path) then
            -- Use \"stream\" mode for music to save memory
            local source = love.audio.newSource(path, "stream")
            source:setVolume(audio_manager.volumes.music * audio_manager.volumes.master)
            audio_manager.music[name] = source
            print("Loaded music: " .. name .. " (" .. path .. ")")
        else
            print("Warning: music file not found: " .. path)
        end
    end
end

-- Load all sound effects
function audio_manager.loadSounds()
    local soundDir = audio_manager.config.soundDir

    for name, filename in pairs(audio_manager.config.soundFiles) do
        local path = soundDir .. "/" .. filename
        if love.filesystem.getInfo(path) then
            -- Use \"static\" mode for sound effects (fully loaded into memory)
            local source = love.audio.newSource(path, "static")
            source:setVolume(audio_manager.volumes.sound * audio_manager.volumes.master)
            audio_manager.sounds[name] = source
            print("Loaded sound: " .. name .. " (" .. path .. ")")
        else
            print("Warning: sound file not found: " .. path)
        end
    end
end

-- Play background music
-- @param name: music name
-- @param loop: whether to loop (default true)
-- @param fadeIn: fade-in time in seconds, nil for no fade-in
function audio_manager.playMusic(name, loop, fadeIn)
    if loop == nil then loop = true end

    local source = audio_manager.music[name]
    if not source then
        print("Warning: music not found: " .. tostring(name))
        return false
    end

    -- If the same music is already playing, do nothing
    if audio_manager.currentMusicName == name and source:isPlaying() then
        return true
    end

    -- Stop current music
    if audio_manager.currentMusic then
        audio_manager.currentMusic:stop()
    end

    -- Play new music
    source:setLooping(loop)
    source:setVolume(audio_manager.volumes.music * audio_manager.volumes.master)

    if fadeIn then
        source:setVolume(0)
        -- TODO: Implement fade-in in update()
    end

    source:play()
    audio_manager.currentMusic = source
    audio_manager.currentMusicName = name

    print("Playing music: " .. name)
    return true
end

-- Stop background music
-- @param fadeOut: fade-out time in seconds, nil to stop immediately
function audio_manager.stopMusic(fadeOut)
    if audio_manager.currentMusic then
        if fadeOut then
            -- TODO: Implement fade-out
            audio_manager.currentMusic:stop()
        else
            audio_manager.currentMusic:stop()
        end

        audio_manager.currentMusic = nil
        audio_manager.currentMusicName = nil
        print("Music stopped")
    end
end

-- Pause background music
function audio_manager.pauseMusic()
    if audio_manager.currentMusic and audio_manager.currentMusic:isPlaying() then
        audio_manager.currentMusic:pause()
        print("Music paused")
    end
end

-- Resume background music
function audio_manager.resumeMusic()
    if audio_manager.currentMusic then
        audio_manager.currentMusic:play()
        print("Music resumed")
    end
end

-- Play a sound effect
-- @param name: sound name
-- @param clone: whether to clone the source (allow overlapping playback)
function audio_manager.playSound(name, clone)
    local source = audio_manager.sounds[name]
    if not source then
        print("Warning: sound not found: " .. tostring(name))
        return false
    end

    if clone then
        -- Clone source to allow overlapping playback
        local clonedSource = source:clone()
        clonedSource:setVolume(audio_manager.volumes.sound * audio_manager.volumes.master)
        clonedSource:play()
    else
        -- Replay original source
        source:stop()
        source:setVolume(audio_manager.volumes.sound * audio_manager.volumes.master)
        source:play()
    end

    return true
end

-- Stop all sound effects
function audio_manager.stopAllSounds()
    for _, source in pairs(audio_manager.sounds) do
        source:stop()
    end
end

-- Set master volume
function audio_manager.setMasterVolume(volume)
    audio_manager.volumes.master = math.max(0, math.min(1, volume))
    audio_manager.updateAllVolumes()
end

-- Set music volume
function audio_manager.setMusicVolume(volume)
    audio_manager.volumes.music = math.max(0, math.min(1, volume))
    audio_manager.updateMusicVolume()
end

-- Set sound volume
function audio_manager.setSoundVolume(volume)
    audio_manager.volumes.sound = math.max(0, math.min(1, volume))
    audio_manager.updateSoundVolume()
end

-- Update all volumes
function audio_manager.updateAllVolumes()
    audio_manager.updateMusicVolume()
    audio_manager.updateSoundVolume()
end

-- Update music volume
function audio_manager.updateMusicVolume()
    local volume = audio_manager.volumes.music * audio_manager.volumes.master
    for _, source in pairs(audio_manager.music) do
        source:setVolume(volume)
    end
end

-- Update sound effect volume
function audio_manager.updateSoundVolume()
    local volume = audio_manager.volumes.sound * audio_manager.volumes.master
    for _, source in pairs(audio_manager.sounds) do
        source:setVolume(volume)
    end
end

-- Get current volume settings
function audio_manager.getVolumes()
    return {
        master = audio_manager.volumes.master,
        music = audio_manager.volumes.music,
        sound = audio_manager.volumes.sound,
    }
end

-- Mute toggle
audio_manager.muted = false
audio_manager.previousVolumes = nil

function audio_manager.toggleMute()
    if audio_manager.muted then
        -- Unmute
        if audio_manager.previousVolumes then
            audio_manager.volumes = audio_manager.previousVolumes
            audio_manager.previousVolumes = nil
            audio_manager.updateAllVolumes()
        end
        audio_manager.muted = false
        print("Unmuted")
    else
        -- Mute
        audio_manager.previousVolumes = {
            master = audio_manager.volumes.master,
            music = audio_manager.volumes.music,
            sound = audio_manager.volumes.sound,
        }
        audio_manager.volumes.master = 0
        audio_manager.updateAllVolumes()
        audio_manager.muted = true
        print("Muted")
    end
end

-- Check mute state
function audio_manager.isMuted()
    return audio_manager.muted
end

-- Cleanup resources
function audio_manager.cleanup()
    audio_manager.stopMusic()
    audio_manager.stopAllSounds()

    for _, source in pairs(audio_manager.music) do
        source:release()
    end

    for _, source in pairs(audio_manager.sounds) do
        source:release()
    end

    audio_manager.music = {}
    audio_manager.sounds = {}
    print("Audio resources cleaned up")
end

-- Update function (for future fade-in/fade-out implementation)
function audio_manager.update(dt)
    -- TODO: Implement fade-in/fade-out here if needed
end

-- Debug info
function audio_manager.getDebugInfo()
    local info = {
        currentMusic = audio_manager.currentMusicName or "none",
        musicCount = 0,
        soundCount = 0,
        volumes = audio_manager.volumes,
        muted = audio_manager.muted,
    }

    for _ in pairs(audio_manager.music) do
        info.musicCount = info.musicCount + 1
    end

    for _ in pairs(audio_manager.sounds) do
        info.soundCount = info.soundCount + 1
    end

    return info
end

-- Print debug info
function audio_manager.printDebugInfo()
    local info = audio_manager.getDebugInfo()
    print("=== Audio system debug info ===")
    print("Current music: " .. info.currentMusic)
    print("Loaded music count: " .. info.musicCount)
    print("Loaded sound count: " .. info.soundCount)
    print("Master volume: " .. info.volumes.master)
    print("Music volume: " .. info.volumes.music)
    print("Sound volume: " .. info.volumes.sound)
    print("Muted: " .. tostring(info.muted))
    print("================================")
end

return audio_manager

