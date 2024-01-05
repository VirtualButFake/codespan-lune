local utils = {}

local codeSpan = require("../codeSpan")
local file = require("../file")
local templateManager = require("../templateManager")
local templates = templateManager.templates

local utf8 = require("../../lib/utf8")

function utils.find(t, pred)
	for pos, value in ipairs(t) do
		if pred(value) then
			return pos
		end
	end
	return nil
end

function utils.concat(t, sep)
	local str = ""

	for _, v in t do
		if typeof(v) == "table" then
			str = str .. v.content .. sep
			continue
		end

		str = str .. v .. sep
	end

	return str
end

function utils.getLinesForSpan(self: codeSpan.codeSpan): lineArray
	local lines: lineArray = {}

	local lineIndex = 0

	local function addLine(lineNumber: number, passedLine: line)
		local lineRange = passedLine.line

		if lines[lineRange.file.name] == nil then
			lines[lineRange.file.name] = {
				index = lineIndex + 1,
				lines = {},
			}

			lineIndex += 1
		end

		for _, line in lines[lineRange.file.name].lines do
			if line.lineNum == lineNumber then
				return
			end
		end

		table.insert(lines[lineRange.file.name].lines, passedLine)
	end

	for _, definedRange in self.ranges do
		for _, line in definedRange.file:getLinesInRange(definedRange) do
			addLine(line.lineNum, line)
		end
	end

	for _, label in self.labels do
		for _, line in label.range.file:getLinesInRange(label.range) do
			addLine(line.lineNum, line)
		end
	end

	for _, color in self.colors do
		for _, line in color.range.file:getLinesInRange(color.range) do
			addLine(line.lineNum, line)
		end
	end

	for _, lineList in lines do
		table.sort(lineList.lines, function(a, b)
			return a.lineNum < b.lineNum
		end)
	end

	return lines
end

function utils.getConsecutiveLines(lines: lineArray): { lineGroupContainer }
	local fileLineGroups: { lineGroupContainer } = {}

	for _, lineList in lines do
		local currentGroup: typeof(lineList)
		local lastLine

		local function appendGroup(line)
			if currentGroup then
				local existingGroup = utils.find(fileLineGroups, function(group)
					return group.fileName == line.file.name and group.index == lineList.index
				end)

				if not existingGroup then
					table.insert(fileLineGroups, {
						fileName = line.file.name,
						index = lineList.index,
						lineGroups = {},
					})
				end

				table.insert(fileLineGroups[#fileLineGroups].lineGroups, currentGroup)
			end
		end

		for i, line in lineList.lines do
			if lastLine == nil or lastLine ~= line.lineNum - 1 then
				appendGroup(line.line)

				currentGroup = {
					combinedLineRange = line.line.file:range(line.line:get()),
					lineNumbers = {},
					file = line.line.file,
				}
			end

			table.insert(currentGroup.lineNumbers, line.lineNum)
			currentGroup.combinedLineRange:set(currentGroup.combinedLineRange:getStart(), line.line:getEnd())
			lastLine = line.lineNum

			if currentGroup and i == #lineList.lines then
				appendGroup(line.line)
			end
		end
	end

	table.sort(fileLineGroups, function(a, b)
		return a.index < b.index
	end)

	return fileLineGroups
end

function utils.getLargestLineString(lines: { lineGroupContainer })
	local largestString = 0

	for _, lineGroup in lines do
		for _, line in lineGroup.lineGroups do
			for _, lineNumber in line.lineNumbers do
				local lineString = tostring(lineNumber)
				largestString = math.max(largestString, #lineString)
			end
		end
	end

	return largestString
end

function utils.findLabelsAndColorsForLine(self: codeSpan.codeSpan, range: file.fileRange)
	local labelsAndColors: {
		{
			type: "label" | "color",
			data: codeSpan.Label | codeSpan.Color,
		}
	} = {}

	if self.labels then
		for _, label in self.labels do
			if label.range:looselyFitsInRange(range) then
				table.insert(labelsAndColors, {
					type = "label",
					data = label,
				})
			end
		end
	end

	if self.colors then
		for _, color in self.colors do
			if color.range:looselyFitsInRange(range) then
				table.insert(labelsAndColors, {
					type = "color",
					data = color,
				})
			end
		end
	end

	table.sort(labelsAndColors, function(a, b)
		if a.type == "label" and b.type == "color" then
			return true
		elseif a.type == "color" and b.type == "label" then
			return false
		end

		if a.type == "label" and b.type == "label" then
			local aStart, aEnd = a.data.range:get()
			local bStart, bEnd = b.data.range:get()

			if aStart == bStart then
				return aEnd < bEnd
			end

			return aStart > bStart
		end

		return a.data.range:getEnd() > b.data.range:getEnd()
	end)

	return labelsAndColors
end

function utils.countArray(t: { any })
	local count = 0

	for i in pairs(t) do
		count = math.max(count, i)
	end

	return count
end

function utils.convertRangeToRelative(
	self: file.file,
	range: file.fileRange,
	lineNumber: number,
	indentAmount: number?,
	minIndent: number?
): file.fileRange
	local relativeRange = range:clone()
	local lineNumRange = self:getRangeForLine(lineNumber)

	indentAmount = range.shouldBeTrimmed and indentAmount or 0
	minIndent = minIndent or 0

	indentAmount = indentAmount :: number - minIndent :: number

	if lineNumRange == nil then
		error("Line number " .. lineNumber .. " does not exist in file " .. self.name)
	end

	relativeRange:set(
		relativeRange:getStart() - lineNumRange:getStart() + 1 + indentAmount - minIndent,
		relativeRange:getEnd() - lineNumRange:getStart() + 1 - minIndent
	)

	return relativeRange
end

function utils.applyColorModifications(
	sourceText: string,
	modifications: { colorModification },
	baseColor: { codeSpan.chalkColor },
	line: number?,
	indentAmount: number?,
	minIndent: number?
)
	local characterTable = {}

	table.sort(modifications, function(a, b)
		return a.priority > b.priority
	end)

	for _, color in modifications do
		local range = color.range

		if line and indentAmount and minIndent then
			local relativeRange = utils.convertRangeToRelative(range.file, range, line, indentAmount, minIndent)

			if relativeRange:getEnd() > 0 then
				range = relativeRange
			end
		end

		local colorStart, colorEnd = range:get()

		for charIdx = math.max(0, colorStart), math.max(colorEnd, 0) do
			if characterTable[charIdx] == nil then
				local letter = utf8.sub(sourceText, charIdx, charIdx)

				for _, clr in color.color do
					letter = clr(letter)
				end

				characterTable[charIdx] = letter
			end
		end
	end

	for charIdx = 1, #sourceText do
		if characterTable[charIdx] == nil then
			local letter = utf8.sub(sourceText, charIdx, charIdx)

			for _, clr in baseColor do
				letter = clr(letter)
			end

			characterTable[charIdx] = letter
		end
	end

	return utils.concat(characterTable, "")
end

function utils.buildString(line: pendingFormatLine, paddingSize: number): string
	local str = line.str

	if line.internalOffset then
		str = (line.padOverwrite or " "):rep(line.internalOffset) .. str
	end

	if line.prefixes then
		local prefix = line.prefixes
		-- color prefix
		local charArray = prefix.content

		-- get largest index in charArray
		local largestIndex = 0

		for index in pairs(charArray) do
			largestIndex = math.max(largestIndex, index)
		end

		for i = 1, largestIndex do
			if charArray[i] == nil then
				charArray[i] = " "
			end
		end

		for char, colors in prefix.colors do
			local letter = charArray[char]

			for _, color in colors do
				letter = color(letter)
			end

			charArray[char] = letter
		end

		str = utils.concat(charArray, "") .. str
	end

	return templateManager.apply(
		templates.lineString,
		tostring(line.lineNum or ""),
		paddingSize,
		str,
		line.overwriteCharacter
	)
end

function utils.findHighestMultilineLabelLevel(self: codeSpan.codeSpan, range: file.fileRange)
	local maxSize = 0

	for _, label in self.labels do
		if not label.range:looselyFitsInRange(range) then
			continue
		end

		if #range.file:getLinesInRange(label.range) == 1 then
			continue
		end

		local amount = #utils.getMultilineLabelsLooselyContainedByRange(self, label, label.range)
		maxSize = math.max(maxSize, amount)
	end

	return maxSize * 2
end

function utils.isOnSameLines(range: file.fileRange, otherRange: file.fileRange)
	local selfLines = range.file:getLinesInRange(range)
	local otherLines = otherRange.file:getLinesInRange(otherRange)

	for _, line in selfLines do
		for _, otherLine in otherLines do
			if line.lineNum == otherLine.lineNum then
				return true
			end
		end
	end

	return false
end

function utils.getMultilineLabelsLooselyContainedByRange(
	self: codeSpan.codeSpan,
	label: codeSpan.Label,
	range: file.fileRange,
	_iteratedLabels: { codeSpan.Label }? -- wow this function name is majestic to say the least
)
	local labels: { codeSpan.Label } = _iteratedLabels or { label }

	for _, otherLabel in self.labels do
		if table.find(labels, otherLabel) then
			continue
		end

		if otherLabel.range:looselyFitsInRange(range) or utils.isOnSameLines(range, otherLabel.range) then
			table.insert(labels, otherLabel)

			local relatedLabels =
				utils.getMultilineLabelsLooselyContainedByRange(self, otherLabel, otherLabel.range, labels)

			for _, relatedLabel in relatedLabels do
				if table.find(labels, relatedLabel) then
					continue
				end

				table.insert(labels, relatedLabel)
			end
		end
	end

	table.sort(labels, function(a, b)
		local aStart, bStart = a.range:getStart(), b.range:getStart()
		local aEnd, bEnd = a.range:getEnd(), b.range:getEnd()

		if aStart == bStart then
			return aStart + aEnd > bStart + bEnd
		end

		return aStart < bStart
	end)

	return labels
end

export type prefix = {
	content: { string },
	colors: { [number]: { codeSpan.chalkColor } },
}

type line = {
	lineNum: number,
	line: file.fileRange,
}

type lineArray = {
	[string]: {
		index: number,
		lines: { line },
	},
}

export type lineGroup = {
	combinedLineRange: file.fileRange,
	lineNumbers: { number },
	file: file.file,
}

export type lineGroupContainer = {
	fileName: string,
	index: number,
	lineGroups: { lineGroup },
}

export type colorModification = {
	range: file.fileRange,
	color: { codeSpan.chalkColor },
	priority: number,
}

export type pendingFormatLine = {
	lineNum: string,
	str: string,
	overwriteCharacter: string?,
	internalOffset: number?,
	prefixes: prefix?,
	createdAsEnd: boolean?,
	padOverwrite: string?,
	isLabel: boolean?,
}

return utils
