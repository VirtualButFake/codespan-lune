--[=[
	@class File
	A utility class to read files and interact with it to create ranges.
	This class is accessible by accessing the ``file`` field on the main module.
]=]
local file = {}

local fs = require("@lune/fs")

local range = require("range")

function file.range(self: file, start: number, finish: number): fileRange?
	local newRange = range.new(start, finish) :: fileRange
	newRange.file = self

	--[=[
		@within fileRange
		@method clone
		@return FileRange -- A new file range with the same start and end as this one
	]=]
	function newRange.clone()
		return self:range(start, finish)
	end

	--[=[
		@within fileRange
		@method trim
		@return FileRange -- Returns the exact same range.

		No functionality for CodeSpan, only for the output; when outputting this CodeSpan, the range will be trimmed to first character it finds, removing whitespace.

		This is especially useful when you're printing a set of lines and want to not show the indentation at the start of the line.
	]=]
	function newRange.trim()
		newRange.shouldBeTrimmed = true
		return newRange
	end

	return newRange
end

--[=[
	@tag constructor

	@function fromPath
	@within File
	@param path string -- The path to this file
	@param name string -- The name that this file should be given inside error messages
	@return File

	Creates a new file by reading the contents of a file at a path.
]=]
function file.fromPath(path: string, name: string): file?
	assert(fs.isDir(path) ~= true, `Path "{path}" points to a directory. A file can only be created from a file path.`)
	assert(fs.isFile(path), `Path "{path}" does not point to a file.`)

	local contents = fs.readFile(path)
	return file.fromString(name, contents)
end

--[=[
	@tag constructor

	@function fromString
	@within File
	@param name string -- The name that this file should be given inside error messages
	@param content string -- The content of this file
	@return File

	Creates a new file from a string.
]=]
function file.fromString(name: string, content: string): file?
	content = content:gsub("\t", "    ") -- replace tabs with 4 spaces, so we don't run into issues later
	local self = setmetatable({
		name = name,
		content = content,
	}, { __index = file })

	-- split the file into lines
	local lines: { fileRange } = {}
	local len = 0

	for _, line in content:split("\n") do
		table.insert(lines, self:range(len + 1, len + #line + 1)) -- +1 for newline
		len += #line + 1
	end

	self.lines = lines

	return self
end

--[=[
	@method positionToLine
	@within File
	@param position number -- The position to convert to a line number
	@return number? -- The line number
	@return fileRange? -- The range of the line

	Given a position as a number, returns the line number and the line range of the line this position is on.
]=]
function file.positionToLine(self: file, position: number): (number?, fileRange?)
	for i, line in self.lines do
		local startPos, endPos = line:get()
		if startPos <= position and endPos >= position then
			return i, line
		end
	end

	return nil, nil
end

--[=[
	@method getLineRange
	@within File
	@param lineStart number -- The start line number
	@param lineEnd number -- The end line number
	@return fileRange? -- The range of the lines

	Returns the range created by the start of the first line and the end of the last line.
]=]
function file.getLineRange(self: file, lineStart: number, lineEnd: number): fileRange?
	local startLine = self.lines[lineStart]
	local endLine = self.lines[lineEnd]

	assert(startLine ~= nil and endLine ~= nil, "Line is out of bounds of the file.")

	return self:range(startLine:getStart(), endLine:getEnd())
end

--[=[
	@method getRangeForLine
	@within File
	@param line number -- The line number
	@return fileRange? -- The range of the line

	Returns the range of the line number passed.
]=]
function file.getRangeForLine(self: file, line: number): fileRange?
	local lineRange = self.lines[line]

	assert(lineRange ~= nil, "Line is out of bounds of the file.")

	return self:range(lineRange:getStart(), lineRange:getEnd())
end

--[=[
	@method getRange
	@within File
	@param startCharacter number -- The start character number
	@param endCharacter number -- The end character number
	@return fileRange? -- The range of the characters

	Returns the range of the character numbers passed.
]=]
function file.getRange(self: file, startCharacter: number, endCharacter: number): fileRange?
	assert(startCharacter < 0, "Start character is out of bounds of the file.")
	assert(endCharacter > self.lines[#self.lines]:getEnd(), "End character is out of bounds of the file.")

	return self:range(startCharacter, endCharacter)
end

--[=[
	@method getContentForRange
	@within File
	@param contentRange fileRange -- The range of the content
	@return string? -- The content of the file for the range

	Returns the content of the file for the range passed.
]=]
function file.getContentForRange(self: file, contentRange: fileRange): string?
	return self.content:sub(contentRange:get())
end

--[=[
	@method getNormalizedContentForRange
	@within File
	@param contentRange fileRange -- The range of the content
	@return string? -- The content of the file for the range

	Returns the content of the file for the range passed, with the indentation normalized (finds lowest indentation, and remove all preceding indentation).
]=]
function file.getNormalizedContentForRange(self: file, contentRange: fileRange): string?
	-- first trim the range to start & end of their lines
	local startLineNum, startLine = self:positionToLine(contentRange:getStart())
	local endLineNum, endLine = self:positionToLine(contentRange:getEnd())
	contentRange:set(startLine:getStart(), endLine:getEnd())

	-- now, for each line, capture the amount of spaces or tabs at the start of the line
	local indentationData: {
		{
			line: number,
			indentation: number,
			content: string,
			contentWithoutIndentation: string,
		}
	} =
		{}

	local repeatCharacter = " "

	for i = startLineNum, endLineNum do
		local lineContent = self:getContentForRange(self.lines[i])

		local indentation = lineContent:match("^[\t ]*")
		local indentedSingle = lineContent:match("^[\t ]")

		repeatCharacter = indentedSingle or repeatCharacter

		if indentedSingle and indentedSingle ~= repeatCharacter then
			error("Mixed indentation found in file " .. self.name .. " at line " .. i .. ".")
		end

		if indentation then
			table.insert(indentationData, {
				line = i,
				indentation = #indentation,
				content = lineContent,
				contentWithoutIndentation = lineContent:sub(#indentation + 1),
			})
		else
			table.insert(indentationData, {
				line = i,
				indentation = 0,
				content = lineContent,
				contentWithoutIndentation = lineContent,
			})
		end
	end

	-- this does not cover every case, such as mixed tab/space indentation
	-- but it should be good enough for now

	-- find the minimum indentation
	local clonedIndentationData = table.clone(indentationData)
	table.sort(clonedIndentationData, function(a, b)
		if a.contentWithoutIndentation == "" then
			return false
		elseif b.contentWithoutIndentation == "" then
			return true
		end

		return a.indentation < b.indentation
	end)

	local minIndentation = clonedIndentationData[1]

	if minIndentation == nil then
		-- this means that we were passed 1 line - there's only 1 index, so nothing to sort. we have to loop through the table to find the min
		for _, line in indentationData do
			minIndentation = line
			break
		end

		assert(minIndentation ~= nil, "Could not find lowest indentation for lines. Was a line properly passed?")
	end

	-- offset all lines by their indentation - min indentation
	local normalizedLines: { string } = {}
	local normalizedNumbers: { number } = {}

	for _, line in indentationData do
		local offset = line.indentation - minIndentation.indentation
		local offsetString = repeatCharacter:rep(offset)

		table.insert(normalizedLines, offsetString .. line.contentWithoutIndentation)
		normalizedNumbers[line.line] = line.indentation
	end

	return table.concat(normalizedLines, ""), normalizedNumbers, minIndentation.indentation
end

--[=[
	@within File
	@interface line
	@field lineNum number -- The line number
	@field line fileRange -- The range of the line
]=]
type line = {
	lineNum: number,
	line: fileRange,
}

--[=[
	@method getLinesInRange
	@within File
	@param contentRange fileRange -- The range of the content
	@return { line } -- The lines of the file for the range
	
	Returns the lines of the file for the range passed.
]=]
function file.getLinesInRange(self: file, contentRange: fileRange): { { lineNum: number, line: fileRange } }
	local lines: {
		{
			lineNum: number,
			line: fileRange,
		}
	} = {}

	for lineNum, line in self.lines do
		if line:looselyFitsInRange(contentRange) or contentRange:looselyFitsInRange(line) then
			table.insert(lines, {
				lineNum = lineNum,
				line = line,
			})
		end
	end

	return lines
end

--[=[

	@class fileRange
	Inherits from [Range](Range), functionally identical but has a few edited methods.
]=]
export type fileRange = {
	file: file,
	trim: (fileRange) -> fileRange,
	shouldBeTrimmed: boolean?,
} & range.range

export type file = typeof(setmetatable(
	{} :: {
		name: string,
		content: string,
		lines: { fileRange },
	},
	{ __index = file }
))

return file
