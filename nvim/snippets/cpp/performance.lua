-- C++ snippets: performance. LSP/VSCode syntax: ${1:default}, $1 mirrors, $0 = final cursor.
-- The [C++NN] tag in each description is the minimum standard the snippet needs.

local ls = require("luasnip")
local function S(trig, desc, body)
	return ls.parser.parse_snippet({ trig = trig, desc = desc }, body)
end

return {
	-- Performance
	S("cacheline", "[C++17] cache-line aligned member (avoid false sharing)", "alignas(std::hardware_destructive_interference_size) ${1:std::atomic<int>} ${2:counter}{};"),
	S("likely", "[C++20] [[likely]] / [[unlikely]] branch", [=[
if (${1:cond}) [[${2:likely}]] {
    $0
}]=]),

	-- Low level / low latency
	S("asmx", "[GNU] extended inline asm (outputs : inputs : clobbers)", [=[
${1:std::uint64_t} ${2:out};
asm volatile("${3:mov %1, %0}"
             : "=r"($2)
             : "r"(${4:in})
             : ${5:"cc", "memory"});]=]),
	S("rdtsc", "[GNU x86] read the cycle counter (rdtscp, ordered)", [=[
inline std::uint64_t rdtsc() noexcept {
    std::uint32_t lo, hi, aux;
    asm volatile("rdtscp" : "=a"(lo), "=d"(hi), "=c"(aux));
    return (std::uint64_t{hi} << 32) | lo;
}]=]),
	S("cpusup", "[GNU] pick an implementation by CPU feature", [=[
${1:auto} ${2:kernel} = __builtin_cpu_supports("${3:avx2}") ? ${4:kernel_avx2} : ${5:kernel_scalar};]=]),
	S("pfetch", "[GNU] prefetch ahead in a loop", "__builtin_prefetch(&${1:a}[${2:i} + ${3:16}], ${4:0} /*0=read 1=write*/, ${5:3} /*locality 0-3*/);"),
	S("hot", "[GNU] always_inline hot / noinline cold function", [=[
[[gnu::always_inline]] inline ${1:int} ${2:fast_path}(${3}) { $4 }
[[gnu::noinline, gnu::cold]] ${5:void} ${6:slow_path}(${7}) { $0 }]=]),
	S("nooptim", "[GNU] keep a value / memory from being optimized away", [=[
template <typename T>
inline void do_not_optimize(const T& value) { asm volatile("" : : "r,m"(value) : "memory"); }
inline void clobber_memory() { asm volatile("" : : : "memory"); }]=]),
	S("branchless", "[C++11] branchless select", "${1:r} = ${2:a} ^ ((${2} ^ ${3:b}) & -static_cast<${4:int}>(${5:cond}));"),
	S("pmr", "[C++17] stack arena with pmr containers", [=[
std::array<std::byte, ${1:4096}> ${2:buffer};
std::pmr::monotonic_buffer_resource ${3:arena}{$2.data(), $2.size()};
std::pmr::vector<${4:int}> ${5:values}{&$3};]=]),
	S("mempool", "[C++17] fixed-size object pool (free list)", [=[
template <typename T, std::size_t N>
class ${1:Pool} {
public:
    $1() {
        for (std::size_t i = 0; i < N; ++i) { free_[i] = N - 1 - i; }
    }
    template <typename... Args>
    T* create(Args&&... args) {
        if (top_ == 0) { return nullptr; }
        auto* slot = reinterpret_cast<T*>(&storage_[free_[--top_]]);
        return std::construct_at(slot, std::forward<Args>(args)...);
    }
    void destroy(T* p) noexcept {
        std::destroy_at(p);
        free_[top_++] = static_cast<std::size_t>(
            reinterpret_cast<Slot*>(p) - storage_.data());
    }

private:
    struct alignas(T) Slot { std::byte bytes[sizeof(T)]; };
    std::array<Slot, N> storage_{};
    std::array<std::size_t, N> free_{};
    std::size_t top_ = N;
};]=]),
	S("spsc", "[C++17] lock-free single-producer single-consumer ring", [=[
template <typename T, std::size_t N>  // N must be a power of two
class ${1:SpscQueue} {
    static_assert((N & (N - 1)) == 0);

public:
    bool push(const T& v) {
        const auto head = head_.load(std::memory_order_relaxed);
        if (head - tail_.load(std::memory_order_acquire) == N) { return false; }
        buf_[head & (N - 1)] = v;
        head_.store(head + 1, std::memory_order_release);
        return true;
    }
    std::optional<T> pop() {
        const auto tail = tail_.load(std::memory_order_relaxed);
        if (tail == head_.load(std::memory_order_acquire)) { return std::nullopt; }
        T v = buf_[tail & (N - 1)];
        tail_.store(tail + 1, std::memory_order_release);
        return v;
    }

private:
    std::array<T, N> buf_{};
    alignas(64) std::atomic<std::size_t> head_{0};
    alignas(64) std::atomic<std::size_t> tail_{0};
};]=]),
	S("pin", "[POSIX] pin the current thread to a CPU", [=[
bool pin_to_cpu(int cpu) {
    cpu_set_t set;
    CPU_ZERO(&set);
    CPU_SET(cpu, &set);
    return pthread_setaffinity_np(pthread_self(), sizeof(set), &set) == 0;
}]=]),
}
