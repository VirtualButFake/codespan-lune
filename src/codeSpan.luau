--[=[
	@class CodeSpan
	Represents file(s) that have been annotated with labels, notes, and colors.
	This class is accessible by accessing the ``file`` field on the main module.
]=]

local codeSpan = {}

local chalk = require("../packages/chalk")
local logger = require("../packages/logger").new(4)

local file = require("file")

--[=[
	@within CodeSpan
	@type SeverityType "Error" | "Bug" | "Warning" | "Note" | "Help"
]=]

--[=[
	@within CodeSpan
	@function new
	@tag constructor
	@param severity SeverityType
	@return CodeSpan

	Creates a new CodeSpan object.
]=]
function codeSpan.new(severity: SeverityType): codeSpan
	return setmetatable({
		severity = severity,
		ranges = {},
		labels = {},
		notes = {},
		header = nil,
		colors = {},
	}, { __index = codeSpan })
end

--[=[
	@within CodeSpan
	@method addRange
	@param passedRange fileRange
	@return CodeSpan

	Adds a range to the CodeSpan object.
	This will make this range visible in the eventual output.
]=]
function codeSpan.addRange(self: codeSpan, passedRange: file.fileRange): codeSpan
	table.insert(self.ranges, passedRange)
	return self
end

--[=[
	@within CodeSpan
	@type LabelStyle "Primary" | "Secondary"

	The difference between these 2 styles is the following:
	- Primary will make the range it targests the color of the severity, use the `^` character to underline the range, and take priority over secondary labels.
	- Secondary will make the range it targets a default color (cyan), and use the `-` character to underline the range.
]=]

--[=[
	@within CodeSpan
	@method addLabel
	@param style LabelStyle
	@param passedRange fileRange
	@param content string
	@return CodeSpan

	Adds a label to the CodeSpan object, with the given style, range, and content. If a label with the same range already exists, it will be ignored.
]=]
function codeSpan.addLabel(self: codeSpan, style: LabelStyle, passedRange: file.fileRange, content: string): codeSpan
	-- check if a label with this range already exists
	for _, label in ipairs(self.labels) do
		if label.range:getStart() == passedRange:getStart() and label.range:getEnd() == passedRange:getEnd() then
			logger:warn(
				"Ignoring added label with range ("
					.. passedRange:getStart()
					.. ", "
					.. passedRange:getEnd()
					.. ") because it already exists."
			)
			return self
		end
	end

	table.insert(self.labels, {
		style = style,
		range = passedRange,
		content = content,
	})

	return self
end

--[=[
	@within CodeSpan
	@method addNote
	@param note string
	@return CodeSpan

	Adds a note to the CodeSpan object. Notes will be displayed at the bottom of the output.
]=]
function codeSpan.addNote(self: codeSpan, note: string): codeSpan
	table.insert(self.notes, note)
	return self
end

--[=[
	@within CodeSpan
	@method addColor
	@param passedRange fileRange
	@param color { chalkColor }
	@return CodeSpan

	Colors a range with a set of [Chalk](https://github.com/grilme99/ChalkLua-NoOp) styles/colors. The Chalk version CodeSpan uses is listed [here](https://raw.githubusercontent.com/jsdotlua/jest-lua/f788c4b0d77175fa32e438eeb169b04dede7e3b1/packages/chalk/src/init.luau).

	Each color or style should be passed seperately, i.e. ``{ Chalk.red, Chalk.bold }`` should be given seperately. The function will then be called on the specified ranges.
]=]
function codeSpan.addColor(self: codeSpan, passedRange: file.fileRange, color: { chalkColor }): codeSpan
	table.insert(self.colors, {
		range = passedRange,
		color = color,
	})
	return self
end

--[=[
	@within CodeSpan
	@method setHeader
	@param code string
	@param message string
	@return CodeSpan

	Sets the header of the CodeSpan object to the given code and message. This will be displayed on top of the output.
]=]
function codeSpan.setHeader(self: codeSpan, code: string, message: string): codeSpan
	self.header = {
		code = code,
		message = message,
	}
	return self
end

type LabelStyle = "Primary" | "Secondary"
type SeverityType = "Error" | "Bug" | "Warning" | "Note" | "Help"

export type Label = {
	style: LabelStyle,
	range: file.fileRange,
	content: string,
	depth: number?,
}

type Header = {
	code: string,
	message: string,
}

export type chalkColor = typeof(chalk.ansi("red"))

export type Color = {
	range: file.fileRange,
	color: { chalkColor },
}

export type codeSpan = typeof(setmetatable(
	{} :: {
		severity: SeverityType,
		ranges: { file.fileRange },
		labels: { Label },
		notes: { string },
		header: Header?,
		colors: { Color },
	},
	{ __index = codeSpan }
))

return codeSpan
