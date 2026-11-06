-- stand_bot_loader.lua
-- paste THIS into your executor. it pulls the full script from GitHub.
local url = "https://raw.githubusercontent.com/qfcl-prog/Stand-bot/main/stand_bot.lua"

local ok, err = pcall(function()
    loadstring(game:HttpGet(url))()
end)

if not ok then
    warn("[stand bot] load failed: " .. tostring(err))
end
