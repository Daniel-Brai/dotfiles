-- C++ snippets: modules. LSP/VSCode syntax: ${1:default}, $1 mirrors, $0 = final cursor.
-- The [C++NN] tag in each description is the minimum standard the snippet needs.

local ls = require("luasnip")
local function S(trig, desc, body)
	return ls.parser.parse_snippet({ trig = trig, desc = desc }, body)
end

return {
	-- Modules
	S("modx", "[C++20] module interface unit", [=[
export module ${1:$TM_FILENAME_BASE};

export namespace $1 {

${2:int} ${3:answer}() { return ${4:42}; }$0

} // namespace $1]=]),
	S("modg", "[C++20] module with global module fragment", [=[
module;
#include <${1:cstdio}>

export module ${2:$TM_FILENAME_BASE};

export ${3:void} ${4:run}() {
    $0
}]=]),
}
