-- Make snippets for C and C++ projects. All triggers start with "cc" so they never get in the
-- way in other Makefiles. Language-neutral ones are in general.lua.

local ls = require("luasnip")
local function S(trig, desc, body)
	return ls.parser.parse_snippet({ trig = trig, desc = desc }, body)
end

return {
	S("ccmk", "C/C++ Makefile: out-of-tree build, header deps, debug/release", [=[
${1|CXX,CC|}      ?= ${2|g++,gcc|}
STD      ?= ${3|c++23,c++20,c++17,c23,c17,c11|}
MODE     ?= debug
BUILD    := build/\$(MODE)
TARGET   := \$(BUILD)/${4:app}
EXT      := ${5|cpp,c|}

SRCS     := \$(wildcard src/*.\$(EXT))
OBJS     := \$(SRCS:src/%.\$(EXT)=\$(BUILD)/%.o)
DEPS     := \$(OBJS:.o=.d)

CPPFLAGS := -Iinclude -MMD -MP
FLAGS    := -std=\$(STD) -Wall -Wextra -Wpedantic -Wshadow -Wconversion
ifeq (\$(MODE),release)
  FLAGS  += -O2 -DNDEBUG
else
  FLAGS  += -O0 -g -fsanitize=address,undefined
  LDFLAGS += -fsanitize=address,undefined
endif

.DELETE_ON_ERROR:
.PHONY: all run clean

all: \$(TARGET)

\$(TARGET): \$(OBJS)
	\$($1) \$(LDFLAGS) \$^ -o \$@

\$(BUILD)/%.o: src/%.\$(EXT) | \$(BUILD)
	\$($1) \$(CPPFLAGS) \$(FLAGS) -c \$< -o \$@

\$(BUILD):
	mkdir -p \$@

run: \$(TARGET)
	./\$(TARGET)

clean:
	rm -rf build

-include \$(DEPS)]=]),
	S("ccpat", "C/C++ object-from-source pattern rule", [=[
\$(BUILD)/%.o: ${1:src}/%.${2|cpp,c|} | \$(BUILD)
	\$(${3|CXX,CC|}) \$(CPPFLAGS) \$(${4|CXXFLAGS,CFLAGS|}) -c \$< -o \$@]=]),
	S("ccdeps", "C/C++ automatic header dependencies (-MMD -MP)", [=[
CPPFLAGS += -MMD -MP
-include \$(${1:OBJS}:.o=.d)]=]),
	S("cclib", "C/C++ static library from objects", [=[
${1:LIB} := \$(BUILD)/lib${2:core}.a
$1: \$(${3:LIB_OBJS})
	\$(AR) rcs \$@ \$^]=]),
	S("cctest", "C/C++ test binary linked against the library objects", [=[
TEST_BIN := \$(BUILD)/tests
\$(TEST_BIN): \$(${1:TEST_OBJS}) \$(${2:LIB_OBJS})
	\$(${3|CXX,CC|}) \$(LDFLAGS) \$^ -o \$@

.PHONY: test
test: \$(TEST_BIN)
	./\$(TEST_BIN)]=]),
	S("ccflags", "clangd compile_flags.txt target (no bear needed)", [=[
.PHONY: compile_flags.txt
compile_flags.txt:
	printf '%s\n' -std=\$(STD) -Iinclude -Wall -Wextra > \$@]=]),
}
