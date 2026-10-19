return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`LakeGang` encountered an error loading the Darktide Mod Framework.")

		new_mod("LakeGang", {
			mod_script       = "LakeGang/scripts/mods/LakeGang/LakeGang",
			mod_data         = "LakeGang/scripts/mods/LakeGang/LakeGang_data",
			mod_localization = "LakeGang/scripts/mods/LakeGang/LakeGang_localization",
		})
	end,
	packages = {},
}
