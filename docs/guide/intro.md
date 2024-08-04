---
outline: [2, 3]
---

# CodeSpan

CodeSpan is a library designed to create beautiful diagnostics for [Lune](https://github.com/filiptibell/lune).
It's extremely easy to use, and is designed to be as flexible as possible.

## Installation

Installation is currently possible through either just pasting the code into your project, or using Git submodules.
More robust installation methods will be available in the future, but there are no widely used package managers for Lune code yet.

### Git Submodule installation

1. Navigate to your project's root directory
2. Run `git submodule add https://github.com/virtualbutfake/codespan-lune path/to/your/submodule`
3. Import the module as you normally would.

## Examples

### Basic usage

```lua
local codespan = require("codespan")

local fileContents = 'print("hi")'
local file = codespan.file.fromString("file_name.txt", fileContents)

local span = codespan.main.new("Error")
span:addLabel("Primary", file:getRangeForLine(1):trim(), "example label")

print(codespan.emitter.out(span))
```

would show the following output:
![Result](https://cdn.tijne.net/geeUyeDEe4sL/direct)

### Multiline labels

Labels can cross lines and intersect with each other, and CodeSpan will figure out the best way to group them.
An example of this can be seen below:

```lua
local codespan = require("codespan")

local fileContents = [[
    local a = 1
    local b = 2

    if a == 1 then
        print("a is 1")
    end
]]

local file = codespan.file.fromString("file_name.txt", fileContents)

local span = codespan.main.new("Error")
span:addLabel("Primary", file:getLineRange(1, 2), "example label 1")
span:addLabel("Secondary", file:getLineRange(2, 5), "example label 2")

print(codespan.emitter.out(span))
```

would show the following output:
![Result](https://cdn.tijne.net/C7uV4poDrO1t/direct)

### Multiple overlapping single-line labels

CodeSpan will also figure out the best way to group multiple overlapping single-line labels, giving priority to the earlier labels.
An example of this can be seen below:

```lua
local codespan = require("codespan")

local fileContents = [[
    local a = 1
    local b = 2

    if a == 1 then
        print("a is 1")
    end
]]

local file = codespan.file.fromString("file_name.txt", fileContents)

local span = codespan.main.new("Error")
span:addLabel("Primary", file:range(5, 8):trim(), "example label 1")
span:addLabel("Secondary", file:range(8, 12):trim(), "example label 2")

print(codespan.emitter.out(span))
```

would show the following output:
![Result](https://cdn.tijne.net/c8qtTHXxjP6i/direct)

(If you're wondering why we're using the range `(5, 8)` instead of starting at 1, there's a newline and 4 spaces before the actual code starts)

### Notes and headers

We can also apply notes to a CodeSpan, which will be shown at the very bottom. I'd recommend keeping notes on 1 line, as while they won't bug out with multiple lines, it'll look a little weird.

```lua
local codespan = require("codespan")

local fileContents = 'print("hi")'
local file = codespan.file.fromString("file_name.txt", fileContents)

local span = codespan.main.new("Note")
span:addLabel("Primary", file:getRangeForLine(1):trim(), "example label")
span:setHeader("N201", "This is a header")
span:addNote("This is a note")

print(codespan.emitter.out(span))
```

would show the following output:
![Result](https://cdn.tijne.net/8Z3NWHiNeIwx/direct)
