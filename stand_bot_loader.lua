-- stand_bot_loader.lua
-- paste THIS into your executor. secrets stay here (local), never in the public repo.
getgenv().Secrets = {
    DiscordToken   = "paste_bot_token_here",    -- discord bot token
    DiscordChannel = "paste_channel_id_here",   -- command channel id (string)
    DiscordEnabled = true,                      -- turn remote control on
    FollowCookie   = "",                        -- this bot's .ROBLOSECURITY (for .follow)
}

local url = "https://raw.githubusercontent.com/qfcl-prog/Stand-bot/main/stand_bot.lua"
local ok, err = pcall(function()
    loadstring(game:HttpGet(url))()
end)

if not ok then
    warn("[stand bot] load failed: " .. tostring(err))
end
