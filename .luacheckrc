-- Lint for the WoW client (Lua 5.1). Reading WoW API globals is fine; writing
-- globals is only allowed for the names below, so a missing `local` fails CI.
std = "lua51"
max_line_length = false
unused_args = false
allow_defined_top = false

ignore = {
	"113", -- accessing undefined global: the WoW API is too large to list
	"431", -- shadowing an upvalue: used on purpose for short-lived locals
}

globals = {
	"ForeverLootSparklesColoringDB", -- SavedVariables
	"SLASH_FLSCOLOR1",
	"SlashCmdList",
	"ColorPickerFrame",
}

exclude_files = {
	".release/",
	"ForeverLootSparkles_Coloring/Libs/",
}
