--[=[
	@class Range
	A wrapper for a range of numbers. Used for storing the start and end positions of a selection, 
	and providing utility functions for working with ranges. 
	This class is accessible by accessing the ``range`` field on the main module.
]=]
local range = {}

--[=[
	@tag constructor

	@function new
	@within Range
	@param startPosition number -- The start position of the range.
	@param endPosition number -- The end position of the range.
	@return Range

	Creates a new range object.
]=]
function range.new(startPosition: number, endPosition: number): range
	return setmetatable({
		startPosition = startPosition,
		endPosition = endPosition,
	}, { __index = range })
end

--[=[
	@method get
	@within Range
	@return number -- The start position of the range.
	@return number -- The end position of the range.

	Gets the start and end positions of the range.
]=]
function range.get(self: range)
	return self.startPosition, self.endPosition
end

--[=[
	@method getStart
	@within Range
	@return number

	Gets the start position of the range.
]=]
function range.getStart(self: range)
	return self.startPosition
end

--[=[
	@method getEnd
	@within Range
	@return number

	Gets the end position of the range.
]=]
function range.getEnd(self: range)
	return self.endPosition
end

--[=[
	@method set
	@within Range
	@param startPosition number -- The new start position of the range.
	@param endPosition number -- The new end position of the range.

	Sets the start and end positions of the range.
]=]
function range.set(self: range, startPosition: number, endPosition: number)
	self.startPosition = startPosition
	self.endPosition = endPosition
end

--[=[   
	@method fitsInRange
	@within Range
	@param passedRange Range -- The range to check if it fits within the range.
	@return boolean -- Whether the range fits within the range.
	@return number? -- The start position of the range if it fits within the range.
	@return number? -- The end position of the range if it fits within the range.

	Checks if the passed range fits within the range. If it does, it returns true, and the start and end positions of the range.
]=]
function range.fitsInRange(self: range, passedRange: range): (number | boolean, number?, number?)
	local passedStart, passedEnd = passedRange:get()
	local selfStart, selfEnd = self:get()

	if passedStart >= selfStart and passedEnd <= selfEnd then
		return true, math.max(selfStart, passedStart), math.min(selfEnd, passedEnd)
	else
		return false
	end
end

--[=[
	@method looselyFitsInRange
	@within Range
	@param passedRange Range -- The range to check if it loosely fits within the range.
	@return boolean -- Whether the range loosely fits within the range.
	@return number? -- The start position of the range if it loosely fits within the range.
	@return number? -- The end position of the range if it loosely fits within the range.

	Checks if the passed range loosely fits within the range. If it does, it returns true, and the start and end positions of the range.

	"Loosely fits" refers to whether any part fits within the range: for example, when passed (10, 20) and (15, 25), it will return true.
	You'd use this when you want to check whether ranges are overlapping, but not necessarily fully contained within each other.

]=]
function range.looselyFitsInRange(self: range, passedRange: range): (number | boolean, number?)
	local passedStart, passedEnd = passedRange:get()
	local selfStart, selfEnd = self:get()

	if passedStart <= selfEnd and passedEnd >= selfStart then
		return true, math.max(passedStart, selfStart), math.min(passedEnd, selfEnd)
	else
		return false
	end
end

--[=[
	@method clone
	@within Range
	@return Range

	Clones the range.
]=]
function range.clone(self: range): range
	return range.new(self:get())
end

--[=[
	@method merge
	@within Range
	@param otherRange Range -- The range to merge with.
	@return Range

	Merges the range with another range, returning a new range that contains both ranges.
]=]
function range.merge(self: range, otherRange: range): range
	local selfStart, selfEnd = self:get()
	local otherStart, otherEnd = otherRange:get()

	return range.new(math.min(selfStart, otherStart), math.max(selfEnd, otherEnd))
end

--[=[
	@interface range
	@within Range

	@field startPosition number -- The start position of the range.
	@field endPosition number -- The end position of the range.
]=]
export type range = typeof(setmetatable(
	{} :: {
		startPosition: number,
		endPosition: number,
	},
	{ __index = range }
))

return range
