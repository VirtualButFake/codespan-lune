
local codespan = require("src")

local fileContents = 'print("hi")'
local file = codespan.file.fromString("file_name.txt", fileContents)

local span = codespan.main.new("Note")
span:addLabel("Primary", file:getRangeForLine(1):trim(), "example label")
span:setHeader("N201", "This is a header")
span:addNote("This is a note")

print(codespan.emitter.out(span))