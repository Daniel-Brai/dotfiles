-- C snippets. Bodies use LSP/VSCode syntax: ${1:default}, $1 mirrors, $0 = final cursor.
-- [C23] marks snippets that need C23 (the default standard here).

local ls = require("luasnip")
local function S(trig, desc, body)
	return ls.parser.parse_snippet({ trig = trig, desc = desc }, body)
end

return {
	S("main", "main(void)", [=[
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    $0
    return EXIT_SUCCESS;
}]=]),
	S("maina", "main with arguments", [=[
int main(int argc, char *argv[]) {
    if (argc < ${1:2}) {
        fprintf(stderr, "usage: %s ${2:<file>}\n", argv[0]);
        return EXIT_FAILURE;
    }
    $0
    return EXIT_SUCCESS;
}]=]),
	S("guard", "include guard", [=[
#ifndef ${1:${TM_FILENAME_BASE/(.*)/${1:/upcase}/}_H}
#define $1

$0

#endif /* $1 */]=]),
	S("doxy", "Doxygen function comment", [=[
/**
 * @brief ${1:What it does.}
 * @param ${2:name} ${3:meaning}
 * @return ${4:what comes back}
 */]=]),
	S("tstruct", "typedef struct", [=[
typedef struct ${1:Name} {
    ${2:int} ${3:field};$0
} $1;]=]),
	S("tenum", "[C23] enum with fixed underlying type + count", [=[
typedef enum ${1:Color} : ${2:unsigned char} {
    ${3:COLOR_RED},
    ${4:COLOR_GREEN},$0
    ${5:COLOR}_COUNT
} $1;]=]),
	S("xenum", "X-macro enum with names", [=[
#define ${1:COLORS}(X) \
    X(${2:RED})          \
    X(${3:GREEN})

typedef enum { $1(${4:AS_ENUM}) } ${5:Color};
static const char *const ${6:color_names}[] = { $1(${7:AS_STRING}) };]=]),
	S("arrlen", "array length macro", "#define ARRAY_LEN(a) (sizeof(a) / sizeof((a)[0]))"),
	S("fori", "for loop with size_t", [=[
for (size_t ${1:i} = 0; $1 < ${2:n}; ++$1) {
    $0
}]=]),
	S("alloc", "[C23] checked malloc (overflow-safe size)", [=[
size_t ${1:bytes};
if (ckd_mul(&$1, ${2:count}, sizeof *${3:p})) {
    ${4:return nullptr;}
}
${5:int} *$3 = malloc($1);
if ($3 == nullptr) {
    ${6:perror("malloc"); return nullptr;}
}
$0
free($3);
$3 = nullptr;]=]),
	S("realloc", "safe realloc through a temporary", [=[
void *${1:tmp} = realloc(${2:buf}, ${3:new_size});
if ($1 == nullptr) {
    ${4:/* $2 is still valid */}
} else {
    $2 = $1;
}]=]),
	S("ckd", "[C23] checked arithmetic (stdckdint.h)", [=[
${1:int} ${2:result};
if (ckd_${3:add}(&$2, ${4:a}, ${5:b})) {
    ${0:/* overflow */}
}]=]),
	S("fgets", "read a line safely with fgets", [=[
char ${1:line}[${2:256}];
if (fgets($1, sizeof $1, ${3:stdin}) != nullptr) {
    $1[strcspn($1, "\n")] = '\0';
    $0
}]=]),
	S("fopen", "open a file with cleanup via goto", [=[
FILE *${1:f} = fopen(${2:path}, "${3:r}");
if ($1 == nullptr) {
    perror($2);
    return ${4:-1};
}
$0
fclose($1);]=]),
	S("cleanup", "single-exit cleanup with goto", [=[
int ${1:rc} = -1;
${2:char *buf = nullptr;}

${3:buf = malloc(n);}
if (${4:buf == nullptr}) {
    goto out;
}
$0
$1 = 0;
out:
    ${5:free(buf);}
    return $1;]=]),
	S("snp", "bounded string build with snprintf", [=[
char ${1:buf}[${2:128}];
int ${3:n} = snprintf($1, sizeof $1, "${4:%s}", ${5:value});
if ($3 < 0 || (size_t)$3 >= sizeof $1) {
    ${0:/* truncated */}
}]=]),
	S("cexpr", "[C23] constexpr object", "constexpr ${1:int} ${2:SIZE} = ${3:64};"),
	S("typeof", "[C23] typeof-based swap macro", "#define SWAP(a, b) do { typeof(a) tmp_ = (a); (a) = (b); (b) = tmp_; } while (0)"),
	S("sassert", "[C23] static_assert without message", "static_assert(${1:sizeof(int) == 4});"),
	S("nodisc", "[C23] [[nodiscard]] function", "[[nodiscard]] ${1:int} ${2:name}(${3:void});"),
	S("embed", "[C23] #embed a file into an array", [=[
static const unsigned char ${1:data}[] = {
#embed "${2:file.bin}"
};]=]),
	S("bitint", "[C23] _BitInt", "unsigned _BitInt(${1:24}) ${2:value} = ${3:0};"),
	S("unreach", "[C23] unreachable()", "unreachable();"),
	S("sw", "switch with [[fallthrough]]", [=[
switch (${1:value}) {
case ${2:0}:
    $3
    [[fallthrough]];
case ${4:1}:
    $0
    break;
default:
    break;
}]=]),
	S("eprintf", "print to stderr", "fprintf(stderr, \"${1:error: %s}\\n\", ${2:msg});"),
	S("timeit", "measure elapsed time with clock_gettime", [=[
struct timespec ${1:t0}, ${2:t1};
clock_gettime(CLOCK_MONOTONIC, &$1);
$0
clock_gettime(CLOCK_MONOTONIC, &$2);
double ${3:ms} = ($2.tv_sec - $1.tv_sec) * 1e3 + ($2.tv_nsec - $1.tv_nsec) / 1e6;]=]),
	S("check", "tiny test assertion macro", [=[
static int failures = 0;
#define CHECK(cond) do { if (!(cond)) { \
    fprintf(stderr, "%s:%d: CHECK failed: %s\n", __FILE__, __LINE__, #cond); \
    ++failures; } } while (0)]=]),
}
