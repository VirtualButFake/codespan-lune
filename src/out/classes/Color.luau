local Color = {}

local utils = require("../utils")
local codeSpan = require("../../codeSpan")

function Color.Render(
	self: codeSpan.Color,
	config: {
		prefixes: utils.prefix,
		stack: { [string]: any },
		colorModifications: { utils.colorModification },
		lineGroup: utils.lineGroup,
		lineNumber: number,
		subLines: {
			{
				content: string,
				modifications: { utils.colorModification },
				isLabel: boolean?,
			}
		},
		addSubLine: (
			subLine: {
				content: string,
				modifications: { utils.colorModification },
				isLabel: boolean?,
			}
		) -> nil,
		codeSpan: codeSpan.codeSpan,
	}
)
	table.insert(config.colorModifications, {
		range = self.range,
		color = self.color,
		priority = 20,
	})
end

return Color
