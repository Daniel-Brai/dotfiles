-- C++ snippets: templates. LSP/VSCode syntax: ${1:default}, $1 mirrors, $0 = final cursor.
-- The [C++NN] tag in each description is the minimum standard the snippet needs.

local ls = require("luasnip")
local function S(trig, desc, body)
	return ls.parser.parse_snippet({ trig = trig, desc = desc }, body)
end

return {
	-- Templates
	S("tfn", "[C++11] function template with perfect forwarding", [=[
template <typename ${1:T}>
${2:auto} ${3:name}($1&& ${4:value}) {
    $0
    return std::forward<$1>($4);
}]=]),
	S("tcls", "[C++11] class template", [=[
template <typename ${1:T}>
class ${2:Box} {
public:
    explicit $2($1 value) : value_{std::move(value)} {}
    [[nodiscard]] const $1& get() const noexcept { return value_; }
    $0
private:
    $1 value_;
};]=]),
	S("vpack", "[C++11] variadic template forwarding a pack", [=[
template <typename... ${1:Args}>
${2:void} ${3:call}($1&&... ${4:args}) {
    ${5:f}(std::forward<$1>($4)...);$0
}]=]),
	S("vfold", "[C++17] fold expression", [=[
template <typename... ${1:Ts}>
auto ${2:sum}(const $1&... ${3:xs}) {
    return (${3} ${4:+} ...);
}]=]),
	S("ifce", "[C++17] if constexpr", [=[
if constexpr (${1:std::is_integral_v<T>}) {
    $2
} else {
    $0
}]=]),
	S("enif", "[C++11] enable_if constraint (pre-C++20)", [=[
template <typename ${1:T}, std::enable_if_t<${2:std::is_arithmetic_v<$1>}, int> = 0>
${3:void} ${4:name}($1 ${5:value}) {
    $0
}]=]),
	S("trait", "[C++14] type trait + _v variable template", [=[
template <typename T>
struct ${1:is_thing} : std::false_type {};

template <>
struct $1<${2:int}> : std::true_type {};

template <typename T>
inline constexpr bool $1_v = $1<T>::value;]=]),
	S("crtp", "[C++11] CRTP base", [=[
template <typename Derived>
class ${1:Base} {
public:
    void ${2:interface}() { derived().${3:impl}(); }

protected:
    $1() = default;

private:
    Derived& derived() { return static_cast<Derived&>(*this); }
};

class ${4:Concrete} : public $1<$4> {
    friend class $1<$4>;
    void $3() { $0 }
};]=]),
	S("dthis", "[C++23] deducing this (replaces CRTP / const overloads)", [=[
template <typename Self>
auto&& ${1:get}(this Self&& self) {
    return std::forward<Self>(self).${2:value_};
}]=]),
	S("policy", "[C++11] policy-based host class", [=[
template <typename ${1:T}, typename ${2:LockPolicy} = ${3:NoLock}>
class ${4:Container} : private $2 {
public:
    void ${5:add}($1 value) {
        auto guard = this->lock();
        items_.push_back(std::move(value));$0
    }

private:
    std::vector<$1> items_;
};]=]),
	S("terase", "[C++11] type erasure (concept/model)", [=[
class ${1:Drawable} {
public:
    template <typename T>
    $1(T obj) : self_{std::make_unique<Model<T>>(std::move(obj))} {}

    void ${2:draw}() const { self_->$2(); }

private:
    struct Concept {
        virtual ~Concept() = default;
        virtual void $2() const = 0;
    };
    template <typename T>
    struct Model final : Concept {
        explicit Model(T o) : obj{std::move(o)} {}
        void $2() const override { obj.$2(); }
        T obj;
    };
    std::unique_ptr<const Concept> self_;
};]=]),

	-- C++20 constraints
	S("concept", "[C++20] concept with requires expression", [=[
template <typename T>
concept ${1:Shape} = requires(const T& t) {
    { t.${2:area}() } -> std::convertible_to<${3:double}>;$0
};]=]),
	S("req", "[C++20] constrained template (requires clause)", [=[
template <typename ${1:T}>
    requires ${2:std::integral<$1>}
${3:auto} ${4:name}($1 ${5:value}) {
    $0
}]=]),
	S("cauto", "[C++20] abbreviated template with constrained auto", [=[
${1:void} ${2:name}(${3:std::integral} auto ${4:value}) {
    $0
}]=]),
}
