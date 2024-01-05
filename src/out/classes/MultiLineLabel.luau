local MultiLineLabel = {}

local utils = require("../utils")
local codeSpan = require("../../codeSpan")

local templateManager = require("../../templateManager")
local templates = templateManager.templates
local usefulCharacters = templateManager.usefulCharacters

local replaceableCharacters = {
	" ",
	"",
	"-",
	usefulCharacters.right,
	usefulCharacters.up,
}

local replaceableCharactersPadding = {
	" ",
	"",
	"-",
	usefulCharacters.right,
}

function padPrefix(prefix: utils.prefix, start: number, length: number, replacement: string?)
	local newPrefix = {
		content = {},
		colors = prefix.colors,
	}

	local indicesPadded = {}

	for i = 1, start do
		newPrefix.content[i] = prefix.content[i]
	end

	for i = start, math.max(start + length, #prefix.content) do
		if prefix.content[i] == nil or table.find(replaceableCharactersPadding, prefix.content[i]) then
			newPrefix.content[i] = replacement or usefulCharacters.right
			table.insert(indicesPadded, i)
		else
			newPrefix.content[i] = prefix.content[i]
		end
	end

	return newPrefix, indicesPadded
end

function setIndexInPrefix(prefix: utils.prefix, index: number, content: string): nil
	if prefix.content[index] == nil or table.find(replaceableCharacters, prefix.content[index]) then
		prefix.content[index] = content
	end

	return
end

function deepCopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == "table" then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepCopy(orig_key)] = deepCopy(orig_value)
		end
		setmetatable(copy, deepCopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

local lastDeletion = 0
local pendingDeletionStack = {}

function MultiLineLabel.Render(
	self: codeSpan.Label,
	config: {
		prefixes: utils.prefix,
		stack: {
			[string]: any,
			multiLineLabels: {
				{
					label: codeSpan.Label,
					lineSpan: { number },
				}
			},
			labelStack: {
				{
					label: codeSpan.Label,
					lineSpan: { number },
				}
			},
		},
		colorModifications: { utils.colorModification },
		lineGroup: utils.lineGroup,
		lineNumber: number,
		allLines: { utils.pendingFormatLine },
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
		indentAmount: number,
	}
)
	if lastDeletion ~= config.lineNumber then
		lastDeletion = config.lineNumber

		for i, label in pendingDeletionStack do
			table.remove(
				config.stack.labelStack,
				utils.find(config.stack.labelStack, function(a)
					return a.label == label
				end)
			)
			table.remove(pendingDeletionStack, i)
		end
	end

	local line = config.lineGroup.file.lines[config.lineNumber]

	local isEnd = self.range:getEnd() >= line:getStart() and self.range:getEnd() <= line:getEnd()

	if isEnd then
		table.insert(pendingDeletionStack, self)
	end

	if self.depth == nil then
		-- find amount of multiline labels in this range
		local relatedLabels = utils.getMultilineLabelsLooselyContainedByRange(config.codeSpan, self, self.range)
		local depth = table.find(relatedLabels, self)

		self.depth = depth * 2

		local lineSpan = self.range.file:getLinesInRange(self.range)
		local lineNums = {}

		for _, l in ipairs(lineSpan) do
			table.insert(lineNums, l.lineNum)
		end

		table.insert(config.stack.multiLineLabels, {
			lineSpan = lineNums,
			label = self,
		})

		table.insert(config.stack.labelStack, {
			lineSpan = lineNums,
			label = self,
		})
	end

	table.insert(config.colorModifications, {
		range = self.range,
		color = { self.style == "Primary" and templates[config.codeSpan.severity:lower()] or templates.codeColor },
		priority = self.style == "Primary" and 30 or 29,
	})
end

function MultiLineLabel.RenderEnd(
	self: {
		label: codeSpan.Label,
		lineSpan: { number },
	},
	config: {
		lineGroup: utils.lineGroup,
		lines: { utils.pendingFormatLine },
		maxDepth: number,
		severity: string,
		stack: {
			[string]: any,
			multiLineLabels: {
				{
					label: codeSpan.Label,
					lineSpan: { number },
				}
			},
		},
		minIndent: number,
	}
)
	-- iterate through all lines in the lines between the start and end of our line
	local startLine, endLine = self.lineSpan[1], self.lineSpan[#self.lineSpan]
	local depth = self.label.depth :: number

	local lastLine = 0
	local renderStart = true
	local renderEnd = false

	local function addEmptyLine(idx: number): utils.pendingFormatLine
		local line = {
			lineNum = "",
			str = "",
			prefixes = {
				content = {},
				colors = {},
			},
		}

		-- inherit vertical lines from previous line
		local prevLine = config.lines[idx - 1]
		if prevLine and prevLine.prefixes and prevLine.prefixes.content then
			local prevPrefix = prevLine.prefixes
			line.prefixes.content = {}
			line.prefixes.colors = deepCopy(prevPrefix.colors)

			for i = 1, utils.countArray(prevPrefix.content) do
				if prevPrefix.content[i] == usefulCharacters.up then
					line.prefixes.content[i] = usefulCharacters.up
				end
			end
		end

		table.insert(config.lines, idx, line)

		return line
	end

	local color = templates[self.label.style == "Primary" and config.severity:lower() or "default"]

	for idx, line in config.lines do
		if line.lineNum and tonumber(line.lineNum) then
			lastLine = tonumber(line.lineNum)
		end

		if lastLine >= startLine and lastLine <= endLine and not renderEnd then
			-- we're inside of the range of lines we need to render
			if line.prefixes == nil then
				line.prefixes = { content = {}, colors = {} }
			end

			local nextLine = config.lines[idx + 1]

			if renderStart and nextLine and nextLine.isLabel ~= true then
				-- check whether this is at the start of the line
				local lineRange = config.lineGroup.file:getRangeForLine(lastLine)

				-- check whether this is the only label that starts here
				local onlyMultiLabel = true

				for _, label in ipairs(config.stack.multiLineLabels) do
					if label.label.range:getStart() == lineRange:getStart() and label.label ~= self.label then
						onlyMultiLabel = false
						break
					end
				end

				if lineRange and self.label.range:getStart() == lineRange:getStart() and onlyMultiLabel then
					setIndexInPrefix(line.prefixes, depth, usefulCharacters.roundedTop)
					line.prefixes.colors[depth] = { color }
				else
					-- extra line & draw span
					local ln = addEmptyLine(idx + 1)
					setIndexInPrefix(ln.prefixes, depth, usefulCharacters.roundedTop)
					local newPrefix, indicesPadded = padPrefix(ln.prefixes, depth, config.maxDepth - depth)

					ln.padOverwrite = color(usefulCharacters.right)

					ln.prefixes = newPrefix

					for _, i in indicesPadded do
						ln.prefixes.colors[i] = { color }
					end

					local relativeRange =
						utils.convertRangeToRelative(config.lineGroup.file, self.label.range, lastLine)

					local diff = relativeRange:getStart() - 1

					local character = self.label.style == "Primary" and "^" or "'"

					config.lines[idx + 1].str = color(usefulCharacters.right:rep(diff) .. character)
				end

				renderStart = false
			elseif not renderStart then
				setIndexInPrefix(line.prefixes, depth, usefulCharacters.up)
				line.prefixes.colors[depth] = { color }
			end
		elseif lastLine > endLine or renderEnd then
			if not config.lines[#config.lines].createdAsEnd then
				addEmptyLine(idx)
			end

			line = config.lines[idx]

			if line.prefixes == nil then
				line.prefixes = { content = {}, colors = {} }
			end

			setIndexInPrefix(line.prefixes, depth, usefulCharacters.roundedBottom)
			local newPrefix, indicesPadded = padPrefix(line.prefixes, depth, config.maxDepth - depth)

			line.padOverwrite = color(usefulCharacters.right)

			line.prefixes = newPrefix

			for _, i in indicesPadded do
				line.prefixes.colors[i] = { color }
			end

			local lineRange = self.label.range.file:getRangeForLine(self.lineSpan[#self.lineSpan])
			local relativeRange = self.label.range.file:range(
				math.max(self.label.range:getStart(), lineRange:getStart()),
				math.min(self.label.range:getEnd(), lineRange:getEnd())
			)

			local diff = relativeRange:getEnd() - relativeRange:getStart() - config.minIndent
			local character = self.label.style == "Primary" and "^" or "'"

			local splitContent = string.split(self.label.content, "\n")

			line.str = color(usefulCharacters.right:rep(diff) .. character .. " " .. splitContent[1])

			line.createdAsEnd = false

			for i, splitLine in ipairs(splitContent) do
				if i == 1 then
					continue
				end

				-- create lines for the rest of the content
				local ln = addEmptyLine(idx + 1)
				ln.str = color((" "):rep(diff + 2) .. splitLine)
			end

			break
		end

		if config.lines[idx + 1] == nil and not renderEnd then
			-- add a new line to the end for this
			renderEnd = true
			addEmptyLine(idx + 1).createdAsEnd = true
		end

		if tonumber(config.lines[idx + 1].lineNum) and tonumber(config.lines[idx + 1].lineNum) > endLine then
			renderEnd = true
		end
	end
end

return MultiLineLabel
