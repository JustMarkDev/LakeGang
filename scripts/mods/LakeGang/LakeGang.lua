local mod = get_mod("LakeGang")

--[[
	Plays "Lake Gang 1" or "Lake Gang 2" whenever the local player's Psyker starts quelling peril
	(holding Reload) with a weapon enabled in the options (Assail by default). Quelling is the
	`vent_warp_charge` action, which only exists on Psyker weapons and blitzes; the weapon template name
	of the action tells us which one is being used.

	No Audio Plugin / Darktide Local Server needed: sounds are played in-process through the Windows
	MCI API (winmm.dll) via LuaJIT's ffi, which the mod loader exposes as `Mods.lua.ffi`.

	Logging: setup/errors always go to the game's console log as "[MOD][LakeGang][INFO] ...".
	Per-quell details are added when the "Debug logging" option is on.
	Logs: %APPDATA%\Fatshark\Darktide\console_logs
]]

local SOUNDS = {
	"lake_gang_1.wav",
	"lake_gang_2.wav",
}

-- The game's working directory is "binaries", so this is how DMF itself reaches the mods folder
local AUDIO_DIRECTORY = "../mods/LakeGang/audio/"
local ALIAS_PREFIX = "lakegang_"

-- Ignore restarts closer together than this (seconds)
local DEBOUNCE = 0.3

local SND_ASYNC = 0x0001
local SND_NODEFAULT = 0x0002
local SND_FILENAME = 0x00020000

local log = function(message, ...)
	mod:info(message, ...)
end

local debug_log = function(message, ...)
	if mod:get("debug_logging") then
		mod:info(message, ...)
	end
end

local ffi = Mods and Mods.lua and Mods.lua.ffi
local io = Mods and Mods.lua and Mods.lua.io

if not ffi or not io then
	mod:error("needs the mod loader's ffi/io libraries, which were not found (ffi: %s, io: %s). Sounds are disabled.",
		tostring(ffi ~= nil), tostring(io ~= nil))

	return
end

-- Redefining an existing cdef throws (mods reload, or another mod declared it), so declare each one
-- separately and ignore that error
for _, declaration in ipairs({
	"uint32_t mciSendStringA(const char* lpszCommand, char* lpszReturnString, uint32_t cchReturn, void* hwndCallback);",
	"int mciGetErrorStringA(uint32_t mcierr, char* pszText, uint32_t cchText);",
	"int PlaySoundA(const char* pszSound, void* hmod, uint32_t fdwSound);",
	"uint32_t GetFullPathNameA(const char* lpFileName, uint32_t nBufferLength, char* lpBuffer, char** lpFilePart);",
}) do
	pcall(ffi.cdef, declaration)
end

local winmm_loaded, winmm = pcall(ffi.load, "winmm")

if not winmm_loaded then
	mod:error("could not load winmm.dll (%s). Sounds are disabled.", tostring(winmm))

	return
end

local sound_paths = {}
-- true when a sound's MCI alias is open; otherwise we fall back to PlaySound (no volume control)
local mci_open = {}
local current_sound_index
local last_sound_index
local last_play_time = -math.huge

local mci_error_string = function(error_code)
	local buffer = ffi.new("char[256]")

	winmm.mciGetErrorStringA(error_code, buffer, 256)

	return ffi.string(buffer)
end

-- Sends an MCI command; failures are logged unless `quiet` (used for commands expected to fail)
local mci = function(command, quiet)
	local error_code = winmm.mciSendStringA(command, nil, 0, nil)

	if error_code ~= 0 and not quiet then
		log('MCI command "%s" failed: %d %s', command, error_code, mci_error_string(error_code))
	end

	return error_code == 0, error_code
end

local absolute_path = function(relative_path)
	local buffer = ffi.new("char[1024]")
	local length = ffi.C.GetFullPathNameA(relative_path, 1024, buffer, nil)

	return length > 0 and length < 1024 and ffi.string(buffer, length) or relative_path
end

local file_exists = function(path)
	local file = io.open(path, "rb")

	if file then
		file:close()
	end

	return file ~= nil
end

local alias = function(index)
	return ALIAS_PREFIX .. index
end

local close_sounds = function()
	for index = 1, #SOUNDS do
		-- Also closes aliases left open by a previous load of this mod (e.g. after a mods reload)
		mci("close " .. alias(index), true)
		mci_open[index] = nil
	end

	winmm.PlaySoundA(nil, nil, 0)
end

local open_sounds = function()
	close_sounds()

	for index, file_name in ipairs(SOUNDS) do
		local path = absolute_path(AUDIO_DIRECTORY .. file_name)

		sound_paths[index] = path

		if not file_exists(path) then
			mod:echo("Missing sound file: " .. path)
		else
			local success, error_code = mci(string.format('open "%s" type mpegvideo alias %s', path, alias(index)), true)

			if success then
				mci_open[index] = true
				log("opened %s", path)
			else
				log("MCI could not open %s (%d %s), falling back to PlaySound", path, error_code, mci_error_string(error_code))
			end
		end
	end
end

-- Mod volume setting scaled by the game's Master and Sound Effects sliders, as 0-1000 for MCI
local mci_volume = function()
	local master = (Application.user_setting("sound_settings", "option_master_slider") or 100) / 100
	local sfx = (Application.user_setting("sound_settings", "options_sfx_slider") or 100) / 100
	local volume = (mod:get("volume") or 100) / 100

	return math.floor(math.clamp(1000 * master * sfx * volume, 0, 1000))
end

local stop_current_sound = function()
	if not current_sound_index then
		return
	end

	debug_log("stopping %s", SOUNDS[current_sound_index])

	if mci_open[current_sound_index] then
		mci("stop " .. alias(current_sound_index))
	else
		winmm.PlaySoundA(nil, nil, 0)
	end

	current_sound_index = nil
end

local next_sound_index = function()
	if mod:get("playback_mode") == "alternate" then
		return last_sound_index and (last_sound_index % #SOUNDS) + 1 or 1
	end

	return math.random(1, #SOUNDS)
end

local play_lake_gang = function()
	local now = Application.time_since_launch()

	if now - last_play_time < DEBOUNCE then
		debug_log("skipped: quell restarted %.2fs after the last sound", now - last_play_time)

		return
	end

	last_play_time = now

	stop_current_sound()

	local index = next_sound_index()

	last_sound_index = index
	current_sound_index = index

	if mci_open[index] then
		local volume = mci_volume()

		mci(string.format("setaudio %s volume to %d", alias(index), volume))

		local success = mci(string.format("play %s from 0", alias(index)))

		debug_log("playing %s via MCI at volume %d/1000 (%s)", SOUNDS[index], volume, success and "ok" or "failed")
	elseif sound_paths[index] then
		local success = winmm.PlaySoundA(sound_paths[index], nil, bit.bor(SND_ASYNC, SND_NODEFAULT, SND_FILENAME)) ~= 0

		log("playing %s via PlaySound (%s)", SOUNDS[index], success and "ok" or "failed")
	else
		log("cannot play %s: file was not found at load", SOUNDS[index])
	end
end

local is_local_player_unit = function(unit)
	local player = Managers.player and Managers.player:local_player_safe(1)

	return player ~= nil and player.player_unit == unit
end

-- Weapon template name patterns -> setting that enables sounds for that weapon family.
-- "forcesword_2h_" must come before "forcesword_" since both match great swords.
local WEAPON_SETTINGS = {
	{ pattern = "^psyker_throwing_knives", setting_id = "weapon_assail" },
	{ pattern = "^forcesword_2h_", setting_id = "weapon_force_greatswords" },
	{ pattern = "^forcesword_", setting_id = "weapon_force_swords" },
	{ pattern = "^forcestaff_", setting_id = "weapon_force_staffs" },
	{ pattern = "^psyker_smite", setting_id = "weapon_brain_burst" },
	{ pattern = "^psyker_chain_lightning", setting_id = "weapon_smite" },
}

local weapon_template_name = function(action)
	local weapon_template = action._weapon_template
	local weapon_action_component = action._weapon_action_component

	return weapon_template and weapon_template.name
		or weapon_action_component and weapon_action_component.template_name
		or "unknown"
end

local is_weapon_enabled = function(template_name)
	for _, weapon_setting in ipairs(WEAPON_SETTINGS) do
		if template_name:find(weapon_setting.pattern) then
			return mod:get(weapon_setting.setting_id) == true
		end
	end

	return false
end

mod:hook_require("scripts/extension_systems/weapon/actions/action_vent_warp_charge", function(ActionVentWarpCharge)
	log("hooked ActionVentWarpCharge")

	mod:hook_safe(ActionVentWarpCharge, "start", function(self)
		local is_local_unit = self._is_local_unit
		local is_local_player = is_local_player_unit(self._player_unit)

		if not is_local_unit or not is_local_player then
			debug_log("quell ignored: not our character (local unit: %s, local player: %s)",
				tostring(is_local_unit), tostring(is_local_player))

			return
		end

		local template_name = weapon_template_name(self)
		local enabled = is_weapon_enabled(template_name)

		debug_log("quell started with %s (%s)", template_name, enabled and "enabled" or "disabled in options")

		if enabled then
			play_lake_gang()
		end
	end)

	mod:hook_safe(ActionVentWarpCharge, "finish", function(self, reason)
		if not is_local_player_unit(self._player_unit) then
			return
		end

		debug_log("quell finished (reason: %s)", tostring(reason))

		if mod:get("stop_on_release") then
			stop_current_sound()
		end
	end)
end)

mod.on_disabled = function()
	stop_current_sound()
end

mod.on_unload = function()
	close_sounds()
end

mod:command("lakegang", "Play a Lake Gang sound to test the mod", function()
	last_play_time = -math.huge
	play_lake_gang()
end)

log("loading, audio directory: %s", absolute_path(AUDIO_DIRECTORY))
open_sounds()
