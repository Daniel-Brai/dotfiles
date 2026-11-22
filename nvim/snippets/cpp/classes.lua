-- C++ snippets: classes. LSP/VSCode syntax: ${1:default}, $1 mirrors, $0 = final cursor.
-- The [C++NN] tag in each description is the minimum standard the snippet needs.

local ls = require("luasnip")
local function S(trig, desc, body)
	return ls.parser.parse_snippet({ trig = trig, desc = desc }, body)
end

return {
	-- Classes
	S("cls", "[C++11] class with explicit constructor", [=[
class ${1:$TM_FILENAME_BASE} {
public:
    explicit $1(${2:int value}) : ${3:value_}{${4:value}} {}

    $0

private:
    ${5:int} $3{};
};]=]),
	S("rule0", "[C++11] rule of zero: members manage themselves", [=[
struct ${1:Name} {
    ${2:std::string} ${3:name}{};
    ${4:std::vector<int>} ${5:values}{};
    $0
};]=]),
	S("rule5", "[C++11] rule of five: all special members", [=[
class ${1:Name} {
public:
    $1();
    ~$1();

    $1(const $1& other);
    $1& operator=(const $1& other);

    $1($1&& other) noexcept;
    $1& operator=($1&& other) noexcept;
    $0
};]=]),
	S("nocopy", "[C++11] non-copyable, movable", [=[
${1:Name}(const $1&) = delete;
$1& operator=(const $1&) = delete;
$1($1&&) noexcept = default;
$1& operator=($1&&) noexcept = default;]=]),
	S("cmp", "[C++20] defaulted == and <=>", [=[
friend bool operator==(const ${1:Name}&, const $1&) = default;
friend auto operator<=>(const $1&, const $1&) = default;]=]),
	S("raii", "[C++11] RAII owner of a resource", [=[
class ${1:Handle} {
public:
    explicit $1(${2:int} resource) : resource_{resource} {}
    ~$1() { if (resource_ != ${3:-1}) { ${4:close}(resource_); } }

    $1(const $1&) = delete;
    $1& operator=(const $1&) = delete;
    $1($1&& other) noexcept : resource_{std::exchange(other.resource_, $3)} {}
    $1& operator=($1&& other) noexcept {
        std::swap(resource_, other.resource_);
        return *this;
    }

    [[nodiscard]] $2 get() const noexcept { return resource_; }

private:
    $2 resource_;
};]=]),
	S("swap", "[C++11] friend swap + copy-and-swap assignment", [=[
friend void swap(${1:Name}& a, $1& b) noexcept {
    using std::swap;
    swap(a.${2:data_}, b.$2);$0
}

$1& operator=($1 other) noexcept {
    swap(*this, other);
    return *this;
}]=]),
	S("pimpl", "[C++11] pimpl: header part", [=[
class ${1:$TM_FILENAME_BASE} {
public:
    $1();
    ~$1();
    $1($1&&) noexcept;
    $1& operator=($1&&) noexcept;
    $0
private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};]=]),
	S("pimplcpp", "[C++11] pimpl: source part", [=[
struct ${1:$TM_FILENAME_BASE}::Impl {
    $0
};

$1::$1() : impl_{std::make_unique<Impl>()} {}
$1::~$1() = default;
$1::$1($1&&) noexcept = default;
$1& $1::operator=($1&&) noexcept = default;]=]),
	S("nvi", "[C++11] non-virtual interface", [=[
class ${1:Base} {
public:
    virtual ~$1() = default;
    void ${2:run}() { /* checks / logging */ do_$2(); }

private:
    virtual void do_$2() = 0;
};]=]),
	S("iface", "[C++11] abstract interface", [=[
class ${1:Interface} {
public:
    virtual ~$1() = default;
    virtual ${2:void} ${3:method}(${4}) ${5:const} = 0;$0
};]=]),
	S("ovr", "[C++11] override declaration", "${1:void} ${2:method}(${3}) ${4:const }override;"),
	S("singleton", "[C++11] Meyers singleton (thread-safe init)", [=[
class ${1:Registry} {
public:
    static $1& instance() {
        static $1 self;
        return self;
    }
    $1(const $1&) = delete;
    $1& operator=(const $1&) = delete;

private:
    $1() = default;
};]=]),
	S("enumc", "[C++11] enum class with underlying type", [=[
enum class ${1:Color} : ${2:std::uint8_t} {
    ${3:Red},
    ${4:Green},$0
};]=]),
	S("desig", "[C++20] aggregate with designated initializers", [=[
struct ${1:Options} {
    ${2:int} ${3:width} = ${4:80};
    ${5:bool} ${6:verbose} = ${7:false};
};

const $1 ${8:opts}{.$3 = ${9:120}, .$6 = ${10:true}};]=]),
}
