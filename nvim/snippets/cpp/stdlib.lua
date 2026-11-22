-- C++ snippets: stdlib. LSP/VSCode syntax: ${1:default}, $1 mirrors, $0 = final cursor.
-- The [C++NN] tag in each description is the minimum standard the snippet needs.

local ls = require("luasnip")
local function S(trig, desc, body)
	return ls.parser.parse_snippet({ trig = trig, desc = desc }, body)
end

return {
	-- Standard library
	S("uptr", "[C++14] make_unique", "auto ${1:p} = std::make_unique<${2:T}>(${3});"),
	S("sptr", "[C++11] make_shared", "auto ${1:p} = std::make_shared<${2:T}>(${3});"),
	S("uptrd", "[C++11] unique_ptr with custom deleter (FILE*)", [=[
struct ${1:FileCloser} {
    void operator()(std::FILE* f) const noexcept { if (f) { std::fclose(f); } }
};
using ${2:FilePtr} = std::unique_ptr<std::FILE, $1>;

$2 ${3:file}{std::fopen(${4:path}, "${5:rb}")};
if (!$3) {
    $0
}]=]),
	S("opt", "[C++17] function returning std::optional", [=[
std::optional<${1:int}> ${2:find}(${3}) {
    if (${4:found}) {
        return ${5:value};
    }
    return std::nullopt;
}]=]),
	S("visit", "[C++17] std::visit with overloaded lambdas", [=[
template <class... Fs>
struct overloaded : Fs... { using Fs::operator()...; };

std::visit(overloaded{
    [](${1:int} x) { $2 },
    [](${3:const std::string}& s) { $4 },
    [](const auto&) { $0 },
}, ${5:variant});]=]),
	S("exp", "[C++23] function returning std::expected", [=[
enum class ${1:ParseError} { ${2:Empty}, ${3:Invalid} };

std::expected<${4:int}, $1> ${5:parse}(std::string_view ${6:text}) {
    if ($6.empty()) {
        return std::unexpected($1::$2);
    }
    $0
    return ${7:0};
}]=]),
	S("expchain", "[C++23] monadic std::expected chain", [=[
auto ${1:result} = ${2:parse}(${3:input})
    .and_then([](${4:int} v) { return ${5:validate}(v); })
    .transform([](auto v) { return ${6:v * 2}; })
    .or_else([](auto err) { return ${7:fallback}(err); });]=]),
	S("println", "[C++23] std::println", "std::println(\"${1:{}}\", ${2:value});"),
	S("eprintln", "[C++23] std::println to stderr", "std::println(stderr, \"${1:error: {}}\", ${2:value});"),
	S("format", "[C++20] std::format", "std::format(\"${1:{}}\", ${2:value})"),
	S("formatter", "[C++20] std::formatter specialization", [=[
template <>
struct std::formatter<${1:Point}> : std::formatter<std::string_view> {
    auto format(const $1& ${2:p}, std::format_context& ctx) const {
        return std::format_to(ctx.out(), "${3:({}, {})}", ${4:$2.x, $2.y});
    }
};]=]),
	S("span", "[C++20] function taking std::span", [=[
${1:void} ${2:process}(std::span<const ${3:int}> ${4:values}) {
    for (const auto& v : $4) {
        $0
    }
}]=]),
	S("pipe", "[C++20] ranges pipeline", [=[
auto ${1:result} = ${2:items}
    | std::views::filter([](const auto& x) { return ${3:x > 0}; })
    | std::views::transform([](const auto& x) { return ${4:x * x}; })${5:
    | std::ranges::to<std::vector>()};]=]),
	S("mdspan", "[C++23] std::mdspan over a flat buffer", [=[
std::vector<${1:double}> ${2:data}(${3:rows} * ${4:cols});
std::mdspan ${5:m}($2.data(), $3, $4);
for (std::size_t r = 0; r < $5.extent(0); ++r) {
    for (std::size_t c = 0; c < $5.extent(1); ++c) {
        $5[r, c] = ${0:0};
    }
}]=]),
	S("gen", "[C++23] std::generator coroutine", [=[
std::generator<${1:int}> ${2:numbers}(${3:int n}) {
    for (${1} i = 0; i < n; ++i) {
        co_yield i;
    }
}]=]),
	S("readfile", "[C++17] read a whole file into a string", [=[
std::optional<std::string> ${1:read_file}(const std::filesystem::path& path) {
    std::ifstream in(path, std::ios::binary);
    if (!in) {
        return std::nullopt;
    }
    return std::string(std::istreambuf_iterator<char>(in), {});
}]=]),
	S("readlines", "[C++11] read a file line by line", [=[
std::ifstream ${1:in}(${2:path});
for (std::string line; std::getline($1, line);) {
    $0
}]=]),
	S("fsiter", "[C++17] iterate a directory tree (no exceptions)", [=[
std::error_code ec;
for (const auto& entry : std::filesystem::recursive_directory_iterator(${1:root}, ec)) {
    if (entry.is_regular_file()) {
        $0
    }
}
if (ec) {
    ${2:// handle ec.message()}
}]=]),
	S("timeit", "[C++11] measure elapsed time with steady_clock", [=[
const auto ${1:start} = std::chrono::steady_clock::now();
$0
const auto elapsed = std::chrono::duration_cast<std::chrono::${2:microseconds}>(
    std::chrono::steady_clock::now() - $1);]=]),
	S("scopeguard", "[C++17] scope guard (runs on scope exit)", [=[
template <typename F>
class ScopeGuard {
public:
    explicit ScopeGuard(F f) : f_{std::move(f)} {}
    ~ScopeGuard() { if (active_) { f_(); } }
    void dismiss() noexcept { active_ = false; }
    ScopeGuard(const ScopeGuard&) = delete;
    ScopeGuard& operator=(const ScopeGuard&) = delete;

private:
    F f_;
    bool active_ = true;
};

ScopeGuard ${1:cleanup}{[&] { ${0} }};]=]),
	S("factory", "[C++11] factory registry by name", [=[
using ${1:Creator} = std::function<std::unique_ptr<${2:Base}>()>;

std::unordered_map<std::string, $1>& ${3:registry}() {
    static std::unordered_map<std::string, $1> r;
    return r;
}

std::unique_ptr<$2> ${4:create}(const std::string& name) {
    if (auto it = $3().find(name); it != $3().end()) {
        return it->second();
    }
    return nullptr;
}]=]),
	S("fmacro", "[C++20] feature-test macro guard", [=[
#if defined(__cpp_lib_${1:expected}) && __cpp_lib_$1 >= ${2:202211L}
$0
#else
#error "needs __cpp_lib_$1"
#endif]=]),
}
