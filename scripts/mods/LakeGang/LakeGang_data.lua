local mod = get_mod("LakeGang")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "weapons_group",
				type = "group",
				sub_widgets = {
					{ setting_id = "weapon_assail", type = "checkbox", default_value = true },
					{ setting_id = "weapon_force_swords", type = "checkbox", default_value = false },
					{ setting_id = "weapon_force_greatswords", type = "checkbox", default_value = false },
					{ setting_id = "weapon_force_staffs", type = "checkbox", default_value = false },
					{ setting_id = "weapon_brain_burst", type = "checkbox", default_value = false },
					{ setting_id = "weapon_smite", type = "checkbox", default_value = false },
				},
			},
			{
				setting_id = "playback_mode",
				type = "dropdown",
				tooltip = "playback_mode_tooltip",
				default_value = "random",
				options = {
					{ text = "playback_mode_random", value = "random" },
					{ text = "playback_mode_alternate", value = "alternate" },
				},
			},
			{
				setting_id = "volume",
				type = "numeric",
				tooltip = "volume_tooltip",
				default_value = 100,
				range = { 1, 100 },
			},
			{
				setting_id = "stop_on_release",
				type = "checkbox",
				tooltip = "stop_on_release_tooltip",
				default_value = false,
			},
			{
				setting_id = "debug_logging",
				type = "checkbox",
				tooltip = "debug_logging_tooltip",
				default_value = true,
			},
		},
	},
}
