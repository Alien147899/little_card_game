local json = require("core.json")

local profile = {
    data = nil,
}

local PROFILE_FILE = "profile.json"

local function sanitizeName(name)
    if type(name) ~= "string" or name == "" then
        return "Player"
    end
    -- Remove non-ASCII characters to avoid leftover Chinese or other symbols.
    local cleaned = name:gsub("[^%w%p%s]", "")
    if cleaned == "" then
        cleaned = "Player"
    end
    return cleaned
end

local function defaultProfile()
    return {
        name = "Player",
    }
end

local function saveProfile()
    if not profile.data then
        profile.data = defaultProfile()
    end
    local ok, encoded = pcall(json.encode, profile.data)
    if ok then
        love.filesystem.write(PROFILE_FILE, encoded)
    end
end

function profile.load()
    if love.filesystem.getInfo(PROFILE_FILE) then
        local contents = love.filesystem.read(PROFILE_FILE)
        local ok, decoded = pcall(json.decode, contents)
        if ok and type(decoded) == "table" then
            profile.data = decoded
        else
            profile.data = defaultProfile()
        end
    else
        profile.data = defaultProfile()
        saveProfile()
    end
    -- Sanitize name to ensure there are no Chinese or other non-ASCII characters.
    profile.data.name = sanitizeName(profile.data.name)
    saveProfile()
end

function profile.getName()
    return (profile.data and profile.data.name) or "Player"
end

function profile.getAvatarPath()
    return ""
end

function profile.getAvatarImage()
    return nil
end

function profile.setName(name)
    profile.data = profile.data or defaultProfile()
    profile.data.name = sanitizeName(name)
    saveProfile()
end

function profile.listAvatars()
    return {}
end

function profile.setAvatar(_)
    return true
end

function profile.openAvatarFolder()
    return false, "Avatar feature is disabled"
end

return profile
