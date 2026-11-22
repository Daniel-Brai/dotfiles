-- C++ snippets: concurrency. LSP/VSCode syntax: ${1:default}, $1 mirrors, $0 = final cursor.
-- The [C++NN] tag in each description is the minimum standard the snippet needs.

local ls = require("luasnip")
local function S(trig, desc, body)
	return ls.parser.parse_snippet({ trig = trig, desc = desc }, body)
end

return {
	-- Coroutines
	S("task", "[C++20] minimal coroutine task type", [=[
struct ${1:Task} {
    struct promise_type {
        $1 get_return_object() { return {std::coroutine_handle<promise_type>::from_promise(*this)}; }
        std::suspend_always initial_suspend() noexcept { return {}; }
        std::suspend_always final_suspend() noexcept { return {}; }
        void return_void() {}
        void unhandled_exception() { std::terminate(); }
    };
    std::coroutine_handle<promise_type> handle;
    ~$1() { if (handle) { handle.destroy(); } }
    void resume() { handle.resume(); }
};]=]),
	S("awaiter", "[C++20] awaitable type", [=[
struct ${1:Awaiter} {
    bool await_ready() const noexcept { return ${2:false}; }
    void await_suspend(std::coroutine_handle<> h) ${3:noexcept} { $0 }
    ${4:void} await_resume() ${5:noexcept} {}
};]=]),

	-- Concurrency
	S("jthr", "[C++20] jthread with stop_token", [=[
std::jthread ${1:worker}([](std::stop_token st) {
    while (!st.stop_requested()) {
        $0
    }
});]=]),
	S("mtx", "[C++17] mutex + scoped_lock", [=[
std::scoped_lock lock(${1:mutex_});
$0]=]),
	S("shmtx", "[C++17] shared_mutex: readers + writer", [=[
mutable std::shared_mutex ${1:mutex_};

${2:int} ${3:read}() const {
    std::shared_lock lock($1);
    return ${4:value_};
}

void ${5:write}($2 v) {
    std::unique_lock lock($1);
    $4 = v;
}]=]),
	S("cvwait", "[C++11] condition_variable wait with predicate", [=[
std::unique_lock lock(${1:mutex_});
${2:cv_}.wait(lock, [&] { return ${3:ready_}; });
$0]=]),
	S("cvnotify", "[C++11] set state then notify", [=[
{
    std::lock_guard lock(${1:mutex_});
    ${2:ready_} = true;
}
${3:cv_}.notify_${4:one}();]=]),
	S("tsqueue", "[C++17] thread-safe queue", [=[
template <typename T>
class ${1:ConcurrentQueue} {
public:
    void push(T value) {
        {
            std::scoped_lock lock(mutex_);
            queue_.push(std::move(value));
        }
        cv_.notify_one();
    }

    T wait_and_pop() {
        std::unique_lock lock(mutex_);
        cv_.wait(lock, [&] { return !queue_.empty(); });
        T value = std::move(queue_.front());
        queue_.pop();
        return value;
    }

    std::optional<T> try_pop() {
        std::scoped_lock lock(mutex_);
        if (queue_.empty()) {
            return std::nullopt;
        }
        T value = std::move(queue_.front());
        queue_.pop();
        return value;
    }

private:
    std::mutex mutex_;
    std::condition_variable cv_;
    std::queue<T> queue_;
};]=]),
	S("async", "[C++11] std::async with explicit launch policy", [=[
auto ${1:fut} = std::async(std::launch::async, ${2:[] { return 42; }});
$0
auto ${3:result} = $1.get();]=]),
	S("promise", "[C++11] promise / future pair", [=[
std::promise<${1:int}> ${2:promise};
auto ${3:future} = $2.get_future();
std::jthread ${4:producer}([p = std::move($2)]() mutable { p.set_value(${5:42}); });
$0
auto value = $3.get();]=]),
	S("callonce", "[C++11] call_once", [=[
static std::once_flag ${1:flag};
std::call_once($1, [] { $0 });]=]),
	S("atom", "[C++11] atomic counter", "std::atomic<${1:int}> ${2:count}{0};\n$2.fetch_add(1, std::memory_order_${3:relaxed});"),
	S("acqrel", "[C++11] release/acquire publish", [=[
// writer
${1:data} = ${2:compute()};
${3:ready}.store(true, std::memory_order_release);

// reader
while (!$3.load(std::memory_order_acquire)) {}
use($1);]=]),
	S("spin", "[C++20] spinlock on atomic_flag", [=[
class ${1:SpinLock} {
public:
    void lock() noexcept {
        while (flag_.test_and_set(std::memory_order_acquire)) {
            flag_.wait(true, std::memory_order_relaxed);
        }
    }
    void unlock() noexcept {
        flag_.clear(std::memory_order_release);
        flag_.notify_one();
    }

private:
    std::atomic_flag flag_;
};]=]),
	S("latch", "[C++20] latch: wait for N workers", [=[
std::latch ${1:done}{${2:n}};
for (int i = 0; i < $2; ++i) {
    std::jthread([&] { $0 $1.count_down(); }).detach();
}
$1.wait();]=]),
	S("barrier", "[C++20] barrier with completion step", "std::barrier ${1:sync}(${2:n}, [] noexcept { ${3:/* phase done */} });\n$1.arrive_and_wait();"),
	S("sem", "[C++20] counting semaphore", "std::counting_semaphore<${1:4}> ${2:slots}{$1};\n$2.acquire();\n$0\n$2.release();"),
	S("pool", "[C++20] thread pool skeleton", [=[
class ${1:ThreadPool} {
public:
    explicit $1(unsigned n = std::thread::hardware_concurrency()) {
        for (unsigned i = 0; i < n; ++i) {
            workers_.emplace_back([this](std::stop_token st) { run(st); });
        }
    }
    ~$1() {
        for (auto& w : workers_) { w.request_stop(); }
        cv_.notify_all();
    }

    void submit(std::function<void()> job) {
        {
            std::scoped_lock lock(mutex_);
            jobs_.push(std::move(job));
        }
        cv_.notify_one();
    }

private:
    void run(std::stop_token st) {
        while (true) {
            std::function<void()> job;
            {
                std::unique_lock lock(mutex_);
                cv_.wait(lock, st, [&] { return !jobs_.empty(); });
                if (st.stop_requested() && jobs_.empty()) { return; }
                job = std::move(jobs_.front());
                jobs_.pop();
            }
            job();
        }
    }

    std::mutex mutex_;
    std::condition_variable_any cv_;
    std::queue<std::function<void()>> jobs_;
    std::vector<std::jthread> workers_;
};]=]),
	S("par", "[C++17] parallel algorithm (libstdc++ needs -ltbb)", "std::${1:for_each}(std::execution::par, ${2:v}.begin(), $2.end(), ${3:[](auto& x) { x *= 2; }});"),
}
