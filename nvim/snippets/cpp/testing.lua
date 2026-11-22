-- C++ snippets: testing. LSP/VSCode syntax: ${1:default}, $1 mirrors, $0 = final cursor.
-- The [C++NN] tag in each description is the minimum standard the snippet needs.

local ls = require("luasnip")
local function S(trig, desc, body)
	return ls.parser.parse_snippet({ trig = trig, desc = desc }, body)
end

return {
	-- GoogleTest / Benchmark
	S("tst", "GoogleTest TEST", [=[
TEST(${1:Suite}, ${2:DoesThing_WhenCondition}) {
    ${0:EXPECT_EQ(actual, expected);}
}]=]),
	S("tstf", "GoogleTest fixture + TEST_F", [=[
class ${1:Thing}Test : public ::testing::Test {
protected:
    void SetUp() override { $2 }
    void TearDown() override {}

    ${3:Thing} ${4:sut}{};
};

TEST_F($1Test, ${5:StartsEmpty}) {
    $0
}]=]),
	S("tstp", "GoogleTest parameterized TEST_P", [=[
class ${1:Even}Test : public ::testing::TestWithParam<${2:int}> {};

TEST_P($1Test, ${3:Holds}) {
    const auto value = GetParam();
    ${0:EXPECT_TRUE(value % 2 == 0);}
}

INSTANTIATE_TEST_SUITE_P(${4:Small}, $1Test, ::testing::Values(${5:0, 2, 4}));]=]),
	S("tstt", "GoogleTest typed test", [=[
template <typename T>
class ${1:Container}Test : public ::testing::Test {};

using ${2:MyTypes} = ::testing::Types<${3:int, float, double}>;
TYPED_TEST_SUITE($1Test, $2);

TYPED_TEST($1Test, ${4:DefaultIsZero}) {
    ${0:EXPECT_EQ(TypeParam{}, TypeParam{0});}
}]=]),
	S("tstd", "GoogleTest death test", [=[
TEST(${1:Suite}DeathTest, ${2:AbortsOnNull}) {
    EXPECT_DEATH(${3:f(nullptr)}, "${4:.*}");
}]=]),
	S("tstthrow", "GoogleTest EXPECT_THROW", "EXPECT_THROW(${1:statement}, ${2:std::invalid_argument});"),
	S("mock", "gMock mock class + EXPECT_CALL", [=[
class Mock${1:Repo} : public ${2:$1} {
public:
    MOCK_METHOD(${3:int}, ${4:find}, (${5:int id}), (${6:const, override}));
};

TEST(${7:Service}Test, ${8:UsesRepo}) {
    Mock$1 repo;
    EXPECT_CALL(repo, $4(::testing::_)).WillOnce(::testing::Return(${9:1}));
    $0
}]=]),
	S("bench", "Google Benchmark function", [=[
static void BM_${1:Name}(benchmark::State& state) {
    ${2:auto input = make_input(state.range(0));}
    for (auto _ : state) {
        benchmark::DoNotOptimize(${3:work(input)});
        benchmark::ClobberMemory();
    }
    state.SetComplexityN(state.range(0));
}
BENCHMARK(BM_$1)->RangeMultiplier(2)->Range(${4:8}, ${5:8 << 10})->Complexity();]=]),
}
