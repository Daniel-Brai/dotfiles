-- C++ snippets: core. LSP/VSCode syntax: ${1:default}, $1 mirrors, $0 = final cursor.
-- The [C++NN] tag in each description is the minimum standard the snippet needs.

local ls = require("luasnip")
local function S(trig, desc, body)
	return ls.parser.parse_snippet({ trig = trig, desc = desc }, body)
end

return {
	-- Program skeletons
	S("main", "[C++11] main", [=[
int main() {
    $0
    return 0;
}]=]),
	S("maina", "[C++11] main with arguments", [=[
#include <span>
#include <string_view>

int main(int argc, char* argv[]) {
    const std::span args(argv, static_cast<std::size_t>(argc));
    $0
    return 0;
}]=]),
	S("mainstd", "[C++23] import std + println", [=[
import std;

int main() {
    std::println("${1:Hello, world!}");$0
}]=]),
	S("mainp", "[C++23] #include <print> + println", [=[
#include <print>

int main() {
    std::println("${1:Hello, {}!}", ${2:"world"});$0
}]=]),

	-- Headers, namespaces, docs
	S("once", "[C++11] header: #pragma once + namespace", [=[
#pragma once

namespace ${1:$TM_FILENAME_BASE} {

$0

} // namespace $1]=]),
	S("ns", "namespace block", [=[
namespace ${1:name} {

$0

} // namespace $1]=]),
	S("anon", "anonymous namespace (file-local)", [=[
namespace {

$0

} // namespace]=]),
	S("doxy", "Doxygen function comment", [=[
/// \brief ${1:What it does.}
/// \param ${2:name} ${3:meaning}
/// \return ${4:what comes back}
/// \throws ${5:std::exception when ...}]=]),
	S("doxyf", "Doxygen file header", [=[
/// \file $TM_FILENAME
/// \brief ${1:What this file is for.}]=]),

	-- Functions, lambdas, control flow
	S("lam", "[C++11] lambda", "[${1:&}](${2:auto x}) ${3:-> int }{ $0 }"),
	S("rlam", "[C++23] recursive lambda via deducing this", [=[
auto ${1:fib} = [](this auto self, ${2:int} n) -> $2 {
    return n < 2 ? n : self(n - 1) + self(n - 2);
};]=]),
	S("nodisc", "[C++17] [[nodiscard]] function", "[[nodiscard]] ${1:auto} ${2:name}(${3}) ${4:const }noexcept -> ${5:int};"),
	S("cexpr", "[C++11] constexpr function + static_assert", [=[
constexpr ${1:int} ${2:square}($1 x) { return x * x; }
static_assert($2(${3:4}) == ${4:16});]=]),
	S("ceval", "[C++20] consteval function", "consteval ${1:int} ${2:name}(${3:int x}) { return ${4:x}; }"),
	S("ifcev", "[C++23] if consteval", [=[
if consteval {
    $1
} else {
    $0
}]=]),
	S("sbind", "[C++17] structured binding", "auto [${1:a}, ${2:b}] = ${3:pair};"),
	S("ifinit", "[C++17] if with initializer (map lookup)", [=[
if (auto ${1:it} = ${2:map}.find(${3:key}); $1 != $2.end()) {
    $0
}]=]),
	S("forr", "[C++11] range for", [=[
for (${1:const auto&} ${2:item} : ${3:items}) {
    $0
}]=]),
	S("fori", "[C++11] index loop", [=[
for (std::size_t ${1:i} = 0; $1 < ${2:v}.size(); ++$1) {
    $0
}]=]),
	S("forenum", "[C++23] enumerate a range", [=[
for (auto [${1:i}, ${2:x}] : std::views::enumerate(${3:items})) {
    $0
}]=]),
	S("sw", "switch over enum class", [=[
switch (${1:value}) {
case ${2:Kind::A}:
    $0
    break;
default:
    break;
}]=]),
	S("tryc", "[C++11] try / catch", [=[
try {
    $1
} catch (const ${2:std::exception}& e) {
    ${0:std::println(stderr, "error: {}", e.what());}
}]=]),
}
