local chalk = require("../lib/chalk")

local grey = chalk.grey
local red = chalk.red
local magenta = chalk.magenta
local yellow = chalk.yellow
local green = chalk.green
local cyan = chalk.cyan
local white = chalk.white

local bold = chalk.bold

local usefulCharacters = {
	intersection = "├",
	up = "│",
	right = "─",
	top = "┌",
	roundedTop = "╭",
	bottom = "└",
	roundedBottom = "╰",
	intersectionTop = "┬",
	intersectionBottom = "┴",
	fourWay = "┼",
}

local templateStrings = {
	headerError = function(code, message)
		return bold(white(`{bold(red("error[" .. code .. "]"))}: {message}`))
	end,
	headerBug = function(code, message)
		return bold(white(`{bold(magenta("bug[" .. code .. "]"))}: {message}`))
	end,
	headerWarning = function(code, message)
		return bold(white(`{bold(yellow("warning[" .. code .. "]"))}: {message}`))
	end,
	headerNote = function(code, message)
		return bold(white(`{bold(green("note[" .. code .. "]"))}: {message}`))
	end,
	headerHelp = function(code, message)
		return bold(white(`{bold(cyan("help[" .. code .. "]"))}: {message}`))
	end,
	fileBase = function(fileName, startLine, endLine)
		return cyan(`{white(`{fileName}:{startLine}:{endLine}`)}`)
	end,
	lineString = function(lineNumber, paddingLength, lineContent, lineOverwrite)
		return `{cyan(`{(" "):rep(paddingLength)}{lineNumber} {lineOverwrite or usefulCharacters.up}`)} {grey(
			lineContent
		)}`
	end,
	noteTemplate = function(note, padSize)
		return white(`{(" "):rep(padSize)} {cyan("=")} {white(note)}`)
	end,
	error = red,
	bug = magenta,
	warning = yellow,
	note = green,
	help = cyan,
	default = cyan,
	codeColor = grey,
}

return {
	usefulCharacters = usefulCharacters,
	templates = templateStrings,
	apply = function(template, ...)
		if typeof(template) == "string" then
			return template:format(...)
		else
			return template(...)
		end
	end,
}
