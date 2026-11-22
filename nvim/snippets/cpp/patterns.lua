-- C++ snippets: patterns. LSP/VSCode syntax: ${1:default}, $1 mirrors, $0 = final cursor.
-- The [C++NN] tag in each description is the minimum standard the snippet needs.

local ls = require("luasnip")
local function S(trig, desc, body)
	return ls.parser.parse_snippet({ trig = trig, desc = desc }, body)
end

return {
	-- Design patterns
	S("observer", "[C++17] observer with unsubscribe tokens", [=[
template <typename... Args>
class ${1:Signal} {
public:
    using Slot = std::function<void(Args...)>;
    std::size_t subscribe(Slot s) {
        slots_.emplace(next_, std::move(s));
        return next_++;
    }
    void unsubscribe(std::size_t id) { slots_.erase(id); }
    void notify(Args... args) const {
        for (const auto& [id, slot] : slots_) { slot(args...); }
    }

private:
    std::map<std::size_t, Slot> slots_;
    std::size_t next_ = 0;
};]=]),
	S("command", "[C++11] command with undo", [=[
struct ${1:Command} {
    virtual ~$1() = default;
    virtual void execute() = 0;
    virtual void undo() = 0;
};

class ${2:History} {
public:
    void run(std::unique_ptr<$1> c) {
        c->execute();
        done_.push_back(std::move(c));
    }
    void undo() {
        if (done_.empty()) { return; }
        done_.back()->undo();
        done_.pop_back();
    }

private:
    std::vector<std::unique_ptr<$1>> done_;
};]=]),
	S("state", "[C++17] table-driven state machine", [=[
enum class ${1:State} { ${2:Idle}, ${3:Running}, ${4:Done} };
enum class ${5:Event} { ${6:Start}, ${7:Finish} };

const std::map<std::pair<$1, $5>, $1> ${8:transitions}{
    {{$1::$2, $5::$6}, $1::$3},
    {{$1::$3, $5::$7}, $1::$4},
};

std::optional<$1> next($1 s, $5 e) {
    if (auto it = $8.find({s, e}); it != $8.end()) { return it->second; }
    return std::nullopt;
}]=]),
	S("strategy", "[C++20] static (template) and dynamic (function) strategy", [=[
template <typename T>
concept ${1:Formatter} = requires(T f, std::string_view s) { { f(s) } -> std::convertible_to<std::string>; };

template <$1 F>
std::string ${2:render}(std::string_view text, F format) { return format(text); }

using ${3:DynamicFormatter} = std::function<std::string(std::string_view)>;]=]),
}
