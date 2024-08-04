--[=[
    @class Emitter

    This class formats a [CodeSpan](CodeSpan) into a string.
    This class is accessible by accessing the ``emitter`` field on the main module.
]=]
local emitter = {}

local chalk = require("../../lib/chalk")

local codeSpan = require("../codeSpan")
local templateManager = require("../templateManager")
local templates = templateManager.templates
local usefulCharacters = templateManager.usefulCharacters

local utils = require("utils")
local classes = require("classes")

local function formatLineGroup(self: codeSpan.codeSpan, lineGroupContainer: utils.lineGroupContainer)
	local lines: { utils.pendingFormatLine } = {}

	local function addLine(
		content: string,
		lineNum: string?,
		prefixes: utils.prefix?,
		internalOffset: number?,
		overwriteCharacter: string?,
		isLabel: boolean?
	)
		table.insert(
			lines,
			{
				lineNum = lineNum,
				str = content,
				prefixes = prefixes,
				internalOffset = internalOffset,
				overwriteCharacter = overwriteCharacter,
				isLabel = isLabel,
			} :: utils.pendingFormatLine
		)
	end

	local firstLine = lineGroupContainer.lineGroups[1].lineNumbers[1]

	local lastLineGroup = lineGroupContainer.lineGroups[#lineGroupContainer.lineGroups]
	local lastLine = lastLineGroup.lineNumbers[#lastLineGroup.lineNumbers]

	local characterToUse = lineGroupContainer.index == 1 and usefulCharacters.top or usefulCharacters.intersection

	addLine(
		templateManager.apply(templates.fileBase, lineGroupContainer.fileName, firstLine, lastLine),
		nil,
		nil,
		nil,
		characterToUse .. usefulCharacters.right
	)

	for _, lineGroup in lineGroupContainer.lineGroups do
		local stack: {
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
		} =
			{
				labelStack = {},
				multiLineLabels = {},
			}

		local normalizedContent, indentAmount, minIndent =
			lineGroup.file:getNormalizedContentForRange(lineGroup.combinedLineRange)

		for idx, line in normalizedContent:split("\n") do
			local subLines: { subLine } = {}
			local prefix: utils.prefix = {
				content = {},
				colors = {},
			}
			local colorModifications: { utils.colorModification } = {
				{
					range = lineGroup.file:range(1, #line),
					color = { templates.codeColor },
					priority = 0,
				},
			}

			local function addSubLine(subLine: subLine): nil
				table.insert(subLines, subLine) -- will have sidebar & internal padding applied later

				return
			end

			if not lineGroup.lineNumbers[idx] then
				continue
			end

			local lineNum = lineGroup.lineNumbers[idx]
			local rangeForLine = lineGroup.file:getRangeForLine(lineNum)
			local dataForLine = utils.findLabelsAndColorsForLine(self, rangeForLine)

			local passedData = {
				prefixes = prefix,
				stack = stack,
				colorModifications = colorModifications,
				lineGroup = lineGroup,
				subLines = subLines,
				allLines = lines,
				lineNumber = lineNum,
				addSubLine = addSubLine,
				codeSpan = self,
				indentAmount = indentAmount,
				minIndent = minIndent,
			}

			for _, labelOrColor in dataForLine do
				if labelOrColor.type == "color" then
					classes.Color.Render(labelOrColor.data, passedData)
				elseif labelOrColor.type == "label" then
					-- determine whether this label starts & ends at this line
					local label = labelOrColor.data :: codeSpan.Label
					local isMultiLine = label.range:getStart() < rangeForLine:getStart()
						or label.range:getEnd() > rangeForLine:getEnd()

					if isMultiLine then
						classes.MultiLineLabel.Render(label, passedData)
					else
						classes.Label.Render(label, passedData)
					end
				end
			end

			-- apply color modifications
			line = utils.applyColorModifications(
				line,
				colorModifications,
				{ chalk.grey },
				lineNum,
				indentAmount[lineNum],
				minIndent
			)
			addLine(line, tostring(lineNum), prefix)

			for _, subLine in subLines do
				subLine.content = utils.applyColorModifications(subLine.content, subLine.modifications, { chalk.grey })
				addLine(subLine.content, "", nil, nil, nil, subLine.isLabel)
			end
		end

		-- render all multi-line labels
		local highestCount = utils.findHighestMultilineLabelLevel(self, lineGroup.combinedLineRange)

		for _, multiLineLabel in stack.multiLineLabels do
			classes.MultiLineLabel.RenderEnd(multiLineLabel, {
				lineGroup = lineGroup,
				lines = lines,
				maxDepth = highestCount,
				severity = self.severity,
				stack = stack,
				minIndent = minIndent,
			})
		end

		-- determine intenral padding
		for _, line in lines do
			if line.lineNum == nil and line.prefixes == nil and line.overwriteCharacter then
				continue
			end

			if line.prefixes == nil then
				line.prefixes = {
					content = {},
					colors = {},
				}
			end

			local prefixCount = utils.countArray(line.prefixes.content)
			line.internalOffset = highestCount - prefixCount + 1
		end
	end

	return lines
end

--[=[
    @within Emitter
    @function out
    @param self CodeSpan -- The CodeSpan to format.
]=]
function emitter.out(self: codeSpan.codeSpan)
	-- ugly code? put it away in files. problem solved
	local lines = utils.getLinesForSpan(self)
	local lineGroups = utils.getConsecutiveLines(lines)
	local largestLine = utils.getLargestLineString(lineGroups)

	local outputLines: { string } = {}
	local unformattedLines: { { utils.pendingFormatLine } } = {}

	if self.header then
		table.insert(
			outputLines,
			templateManager.apply(templates["header" .. self.severity], self.header.code, self.header.message)
		)
	end

	for _, lineGroupContainer in lineGroups do
		table.insert(unformattedLines, formatLineGroup(self, lineGroupContainer))
	end

	-- format all lines
	for _, line in unformattedLines do
		local lastNum

		for _, preformattedLine in line do
			if preformattedLine.lineNum and preformattedLine.lineNum ~= "" then
				if
					lastNum ~= nil and (preformattedLine.lineNum and tonumber(lastNum) ~= preformattedLine.lineNum - 1)
				then
					table.insert(
						outputLines,
						utils.buildString({ str = "", lineNum = "", overwriteCharacter = "·" }, largestLine)
					)
				end

				lastNum = preformattedLine.lineNum
			end

			local paddingSize = largestLine - #tostring(preformattedLine.lineNum or "")
			table.insert(outputLines, utils.buildString(preformattedLine, paddingSize))
		end
	end

	-- notes
	if self.notes then
		for _, note in self.notes do
			table.insert(outputLines, templateManager.apply(templates.noteTemplate, note, largestLine))
		end
	end

	return table.concat(outputLines, "\n")
end

type subLine = {
	content: string,
	modifications: { utils.colorModification },
	isLabel: boolean?,
}

return emitter
