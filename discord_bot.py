# discord_bot.py
# Discord controller for the Da Hood stand bot.
# secrets live in a .env file next to this script, not in this file.
# run: python discord_bot.py

import os
import discord
from discord import app_commands

# ---- load .env (no extra dependencies) ----
def load_env(path=".env"):
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
    except FileNotFoundError:
        pass

load_env()

TOKEN = os.getenv("DISCORD_TOKEN")
COMMAND_CHANNEL_ID = int(os.getenv("COMMAND_CHANNEL_ID", "0") or 0)

if not TOKEN:
    print("DISCORD_TOKEN missing — check your .env file")
    raise SystemExit(1)
if not COMMAND_CHANNEL_ID:
    print("COMMAND_CHANNEL_ID missing — check your .env file")
    raise SystemExit(1)

intents = discord.Intents.default()
bot = discord.Client(intents=intents)
tree = app_commands.CommandTree(bot)

# command categories for /panel. items in NEEDS_TARGET open a modal for the name.
CATEGORIES = {
    "Combat": ["kill", "lkill", "knock", "lknock", "gkill", "gknock",
               "lgkill", "lgknock", "bend", "blow", "void", "gvoid",
               "sky", "gsky", "frame"],
    "Move": ["bring", "drop", "gbring", "tp", "view"],
    "Protect": ["protect", "unprotect", "save", "unsave", "whitelist",
                "unwhitelist", "team", "psave", "unpsave"],
    "Multi": ["multig", "mkill", "slgkill", "give"],
    "Toggles": ["summon", "vanish", "reset", "fix", "aura", "aheal",
                "aarmor", "adrop", "getback", "asave", "cattack",
                "cgattack", "ctp", "amask", "skill", "ckill",
                "unmultig", "take", "codes"],
    "Farms": ["lfarm", "wfarm", "cfarm", "sfarm"],
    "Clear": ["unwhitelistall", "unteamall", "unprotectall", "unsaveall"],
}

NEEDS_TARGET = {
    "kill", "lkill", "knock", "lknock", "gkill", "gknock", "lgkill", "lgknock",
    "bend", "blow", "void", "gvoid", "sky", "gsky", "frame",
    "bring", "drop", "gbring", "tp", "view",
    "protect", "unprotect", "save", "unsave", "whitelist", "unwhitelist",
    "team", "psave", "unpsave",
    "multig", "mkill", "slgkill", "give",
}


async def post_command(text: str) -> bool:
    ch = bot.get_channel(COMMAND_CHANNEL_ID)
    if ch is None:
        return False
    await ch.send(text)
    return True


class TargetModal(discord.ui.Modal, title="Enter target"):
    def __init__(self, command: str):
        super().__init__()
        self.command = command
        self.target = discord.ui.TextInput(
            label="Roblox username or user ID",
            placeholder="e.g. Bob123 or 2788229",
            required=True,
        )
        self.add_item(self.target)

    async def on_submit(self, interaction: discord.Interaction):
        text = f"{self.command} {self.target.value}"
        ok = await post_command(text)
        await interaction.response.send_message(
            f"sent: `{text}`" if ok else "command channel not found",
            ephemeral=True,
        )


class CommandButton(discord.ui.Button):
    def __init__(self, command: str):
        super().__init__(label=command, style=discord.ButtonStyle.secondary)
        self.command = command

    async def callback(self, interaction: discord.Interaction):
        if self.command in NEEDS_TARGET:
            await interaction.response.send_modal(TargetModal(self.command))
        else:
            ok = await post_command(self.command)
            await interaction.response.send_message(
                f"sent: `{self.command}`" if ok else "command channel not found",
                ephemeral=True,
            )


class CommandView(discord.ui.View):
    def __init__(self, cmds: list):
        super().__init__(timeout=300)
        for c in cmds:
            self.add_item(CommandButton(c))


class CategoryView(discord.ui.View):
    def __init__(self):
        super().__init__(timeout=300)
        opts = [discord.SelectOption(label=k, value=k) for k in CATEGORIES]
        self.select = discord.ui.Select(
            placeholder="choose a category", options=opts
        )
        self.select.callback = self.on_select
        self.add_item(self.select)

    async def on_select(self, interaction: discord.Interaction):
        cat = self.select.values[0]
        view = CommandView(CATEGORIES[cat])
        await interaction.response.edit_message(
            content=f"**{cat}** — pick a command", view=view
        )


@tree.command(name="follow", description="Make all bots follow a player")
@app_commands.describe(user="Roblox username or user ID")
async def follow(interaction: discord.Interaction, user: str):
    ok = await post_command(f"follow {user}")
    await interaction.response.send_message(
        f"sent: `follow {user}`" if ok else "command channel not found",
        ephemeral=True,
    )


@tree.command(name="panel", description="Open the command panel")
async def panel(interaction: discord.Interaction):
    await interaction.response.send_message(
        "pick a category", view=CategoryView(), ephemeral=True
    )


@bot.event
async def on_ready():
    await tree.sync()
    print(f"logged in as {bot.user} — command channel {COMMAND_CHANNEL_ID}")


bot.run(TOKEN)
