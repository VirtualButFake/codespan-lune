local Label = {}

local utils = require("../utils")
local codeSpan = require("../../codeSpan")
local templateManager = require("../../templateManager")
local templates = templateManager.templates

local utf8 = require("../../../lib/utf8")

local replaceableCharacters = {
	" ",
	"",
	"-",
	templateManager.usefulCharacters.up,
}

function addCharactersInString(str: string, index: number, insertString: string): string
	if #str < index then
		str = str .. (" "):rep(index - #str)
	end

	local newStr = ""

	-- go through the string, if a character in the original string is a space we can replace it, otherwise it has to stay intact.
	for i = 1, math.max(#str, index + utf8.len(insertString)) do
		if
			i >= index
			and i < index + utf8.len(insertString)
			and table.find(replaceableCharacters, utf8.sub(str, i, i))
		then
			newStr = newStr .. utf8.sub(insertString, i - index + 1, i - index + 1)
		else
			newStr = newStr .. utf8.sub(str, i, i)
		end
	end

	return newStr
end

function Label.Render(
	self: codeSpan.Label,
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
		indentAmount: { number },
		minIndent: number,
	}
)
	-- figure our whether there's multiple labels on this line
	local rangeForLine = config.lineGroup.file:getRangeForLine(config.lineNumber)

	if not rangeForLine then
		error(`Line number {config.lineNumber} does not exist in file {config.lineGroup.file.name}`)
	end

	local allLabelsCombined = utils.findLabelsAndColorsForLine(config.codeSpan, rangeForLine)
	local relativeSpan = utils.convertRangeToRelative(
		config.lineGroup.file,
		self.range,
		config.lineNumber,
		config.indentAmount[config.lineNumber],
		config.minIndent
	)

	-- check how many of allLabelsCombined are actual multiline labels
	local labelsOnLine = {}

	for _, labelOrColor in allLabelsCombined do
		if labelOrColor.type == "label" then
			local label = labelOrColor.data :: codeSpan.Label

			if label.range:getStart() >= rangeForLine:getStart() and label.range:getEnd() <= rangeForLine:getEnd() then
				table.insert(labelsOnLine, label)
			end
		end
	end

	if self.style == "Primary" then
		table.insert(config.colorModifications, {
			range = relativeSpan,
			color = { templates[config.codeSpan.severity:lower()] },
			priority = 30,
		})
	end

	if #labelsOnLine == 1 then
		-- this data'll be stored directly under the line
		local subLine = config.subLines[1] or {
			content = "",
			modifications = {},
		}

		local len = relativeSpan:getEnd() - relativeSpan:getStart() + 1
		local repeatCharacter = self.style == "Primary" and "^" or "-"

		-- split subline content if it's multiple lines
		local splitContent = string.split(self.content, "\n")

		subLine.content = addCharactersInString(
			subLine.content,
			relativeSpan:getStart(),
			utf8.rep(repeatCharacter, len) .. " " .. splitContent[1]
		)

		subLine.isLabel = true

		config.addSubLine(subLine)

		for i, line in splitContent do
			if i == 1 then
				continue
			end

			-- create new sublines
			config.addSubLine({
				content = (" "):rep(relativeSpan:getStart() + len) .. line,
				modifications = {
					{
						range = config.lineGroup.file:range(
							relativeSpan:getStart(),
							relativeSpan:getEnd() + len + #line
						),
						color = { templates[self.style == "Primary" and config.codeSpan.severity:lower() or "default"] },
						priority = 30,
					},
				},
			})
		end

		table.insert(subLine.modifications, {
			range = config.lineGroup.file:range(relativeSpan:getStart(), relativeSpan:getEnd() + #self.content + 1),
			color = { templates[self.style == "Primary" and config.codeSpan.severity:lower() or "default"] },
			priority = 30,
		})
	else
		-- 2 labels on 1 line
		-- place 1 subline for the main line
		-- then 1 subline for each label, with a vertical line pointing up to the main line
		local subLine = config.subLines[1] or {
			content = "",
			modifications = {},
		}

		local len = relativeSpan:getEnd() - relativeSpan:getStart() + 1
		local repeatCharacter = self.style == "Primary" and "^" or "-"

		subLine.content = addCharactersInString(subLine.content, relativeSpan:getStart(), repeatCharacter:rep(len))

		table.insert(subLine.modifications, {
			range = config.lineGroup.file:range(relativeSpan:getStart(), relativeSpan:getEnd()),
			color = { templates[self.style == "Primary" and config.codeSpan.severity:lower() or "default"] },
			priority = self.style == "Primary" and 30 or 29,
		})

		if subLine ~= config.subLines[1] then
			config.addSubLine(subLine)
			config.addSubLine({
				content = "",
				modifications = {},
			})
		end

		-- now add the line with our content
		for idx, subline in config.subLines do
			if idx == 1 then
				continue
			end

			if
				table.find(
					replaceableCharacters,
					utf8.sub(subline.content, relativeSpan:getStart(), relativeSpan:getStart())
				)
			then
				subline.content =
					addCharactersInString(subline.content, relativeSpan:getStart(), templateManager.usefulCharacters.up)

				table.insert(subline.modifications, {
					range = config.lineGroup.file:range(relativeSpan:getStart(), relativeSpan:getStart()),
					color = { templates[self.style == "Primary" and config.codeSpan.severity:lower() or "default"] },
					priority = 30,
				})
			end
		end

		local splitContent = string.split(self.content, "\n")

		config.addSubLine({
			content = (" "):rep(relativeSpan:getStart() - 1) .. splitContent[1],
			modifications = {
				{
					range = config.lineGroup.file:range(relativeSpan:getStart(), relativeSpan:getEnd() + #self.content),
					color = { templates[self.style == "Primary" and config.codeSpan.severity:lower() or "default"] },
					priority = 30,
				},
			},
		})

		for i, line in splitContent do
			if i == 1 then
				continue
			end

			-- create new sublines
			config.addSubLine({
				content = (" "):rep(relativeSpan:getStart() - 1) .. line,
				modifications = {
					{
						range = config.lineGroup.file:range(
							relativeSpan:getStart(),
							relativeSpan:getEnd() + len + #line
						),
						color = { templates[self.style == "Primary" and config.codeSpan.severity:lower() or "default"] },
						priority = 30,
					},
				},
			})
		end
	end
end

return Label
