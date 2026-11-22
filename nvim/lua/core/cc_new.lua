-- :CNew [name]: scaffold a C or C++ project.
--
-- Kinds:  application, application + library, library, header-only library
-- Build:  CMake (presets, FetchContent GoogleTest) or Make (auto header deps, compile_flags.txt)
-- Tiers:  minimal       one target, warnings on, compile_commands for clangd
--         intermediate  + tests, presets (debug/release/asan), .clang-tidy, install/export for libraries
--         robust        + hardening, LTO, ccache/mold, clang-tidy/coverage/tsan/profile/native presets,
--                         benchmarks, Doxygen, CPack, version header, export macros, GitHub Actions CI
--                         (CMake only)

local M = {}

local GTEST_TAG = { [11] = "release-1.12.1", [14] = "v1.16.0", default = "v1.18.0" }
local BENCHMARK_TAG = "v1.10.0" -- needs C++17

local function render(s, v)
	return (s:gsub("%%%%(%w+)%%%%", function(k)
		return v[k] or ("%%" .. k .. "%%")
	end))
end

local function vars(o)
	local cpp = o.lang == "cpp"
	local std = o.std
	local v = {
		name = o.name,
		NAME = o.name:upper(),
		ext = cpp and "cpp" or "c",
		hext = cpp and "hpp" or "h",
		LANG = cpp and "CXX" or "C",
		std = tostring(std),
		stdflag = (cpp and "c++" or "c") .. std,
		feature = (cpp and "cxx_std_" or "c_std_") .. std,
		CC = cpp and "CXX" or "CC",
		compiler = cpp and "g++" or "gcc",
		FLAGS = cpp and "CXXFLAGS" or "CFLAGS",
		xlang = cpp and "c++" or "c",
		gtest = GTEST_TAG[std] or GTEST_TAG.default,
		benchmark = BENCHMARK_TAG,
	}
	-- which CMake target the tests/examples link against
	v.target = o.kind == "app_lib" and (o.name .. "::lib") or (o.name .. "::" .. o.name)
	return v
end

-- Every project gets one small, testable function so there is something real to build, test and debug

local function cpp_word_count_body()
	return [[
    std::size_t count = 0;
    bool in_word = false;
    for (const char c : text) {
        const bool space = std::isspace(static_cast<unsigned char>(c)) != 0;
        if (!space && !in_word) {
            ++count;
        }
        in_word = !space;
    }
    return count;]]
end

local function c_word_count_body()
	return [[
    size_t count = 0;
    bool in_word = false;
    for (const char *p = text; *p != '\0'; ++p) {
        const bool space = isspace((unsigned char)*p) != 0;
        if (!space && !in_word) {
            ++count;
        }
        in_word = !space;
    }
    return count;]]
end

local function cpp_sig(o, export)
	local sv = o.std >= 17 and "std::string_view" or "const std::string&"
	local nodiscard = o.std >= 17 and "[[nodiscard]] " or ""
	return ("%s%sstd::size_t word_count(%s text) noexcept"):format(nodiscard, export and (o.name:upper() .. "_EXPORT ") or "", sv)
end

local function cpp_string_include(o)
	return o.std >= 17 and "#include <string_view>" or "#include <string>"
end

-- Public header. `inline_def`: header-only (definition in the header). `export`: robust shared-lib macro.
local function cpp_header(o, inline_def, export)
	local lines = { "#pragma once", "" }
	if export then
		table.insert(lines, ('#include "%s/export.hpp"'):format(o.name))
		table.insert(lines, "")
	end
	if inline_def then
		table.insert(lines, "#include <cctype>")
	end
	vim.list_extend(lines, { "#include <cstddef>", cpp_string_include(o), "", "namespace " .. o.name .. " {", "" })
	table.insert(lines, "/// \\brief Counts the whitespace-separated words in `text`.")
	if inline_def then
		table.insert(lines, "inline " .. cpp_sig(o, false):gsub("^%[%[nodiscard%]%] ", "") .. " {")
		if o.std >= 17 then
			lines[#lines] = "[[nodiscard]] " .. lines[#lines]
		end
		table.insert(lines, cpp_word_count_body())
		table.insert(lines, "}")
	else
		table.insert(lines, cpp_sig(o, export) .. ";")
	end
	vim.list_extend(lines, { "", "} // namespace " .. o.name, "" })
	return table.concat(lines, "\n")
end

local function cpp_source(o, header)
	return table.concat({
		('#include "%s"'):format(header),
		"",
		"#include <cctype>",
		"",
		"namespace " .. o.name .. " {",
		"",
		cpp_sig(o, false):gsub("^%[%[nodiscard%]%] ", "") .. " {",
		cpp_word_count_body(),
		"}",
		"",
		"} // namespace " .. o.name,
		"",
	}, "\n")
end

local function c_header(o, inline_def, export)
	local guard = o.name:upper() .. "_" .. o.name:upper() .. "_H"
	local lines = { "#ifndef " .. guard, "#define " .. guard, "" }
	if export then
		vim.list_extend(lines, { ('#include "%s/export.h"'):format(o.name), "" })
	end
	if inline_def then
		vim.list_extend(lines, { "#include <ctype.h>", "#include <stdbool.h>" })
	end
	vim.list_extend(lines, { "#include <stddef.h>", "", "#ifdef __cplusplus", 'extern "C" {', "#endif", "" })
	table.insert(lines, "/** Counts the whitespace-separated words in `text`. */")
	if inline_def then
		table.insert(lines, ("static inline size_t %s_word_count(const char *text) {"):format(o.name))
		table.insert(lines, c_word_count_body())
		table.insert(lines, "}")
	else
		table.insert(lines, ("%ssize_t %s_word_count(const char *text);"):format(export and (o.name:upper() .. "_EXPORT ") or "", o.name))
	end
	vim.list_extend(lines, { "", "#ifdef __cplusplus", "}", "#endif", "", "#endif /* " .. guard .. " */", "" })
	return table.concat(lines, "\n")
end

local function c_source(o, header)
	return table.concat({
		('#include "%s"'):format(header),
		"",
		"#include <ctype.h>",
		"#include <stdbool.h>",
		"",
		("size_t %s_word_count(const char *text) {"):format(o.name),
		c_word_count_body(),
		"}",
		"",
	}, "\n")
end

-- A main() that prints something; `uses_lib` calls word_count from `header`
local function cpp_main(o, header)
	local inc, body = {}, {}
	if header then
		table.insert(inc, ('#include "%s"'):format(header))
		table.insert(inc, "")
	end
	local call = header and (o.name .. '::word_count("hello from ' .. o.name .. '")') or nil
	if o.std >= 23 then
		table.insert(inc, "#include <print>")
		body = header and { "    std::println(\"{} words\", " .. call .. ");" } or { '    std::println("Hello from {}!", "' .. o.name .. '");' }
	elseif o.std >= 20 then
		vim.list_extend(inc, { "#include <format>", "#include <iostream>" })
		body = header and { '    std::cout << std::format("{} words\\n", ' .. call .. ");" } or { '    std::cout << std::format("Hello from {}!\\n", "' .. o.name .. '");' }
	else
		table.insert(inc, "#include <iostream>")
		body = header and { "    std::cout << " .. call .. ' << " words\\n";' } or { '    std::cout << "Hello from ' .. o.name .. '!\\n";' }
	end
	return table.concat(vim.list_extend(vim.list_extend(inc, { "", "int main() {" }), vim.list_extend(body, { "    return 0;", "}", "" })), "\n")
end

local function c_main(o, header)
	local lines = {}
	if header then
		vim.list_extend(lines, { ('#include "%s"'):format(header), "" })
	end
	vim.list_extend(lines, { "#include <stdio.h>", "#include <stdlib.h>", "", "int main(void) {" })
	if header then
		table.insert(lines, ('    printf("%%zu words\\n", %s_word_count("hello from %s"));'):format(o.name, o.name))
	else
		table.insert(lines, ('    printf("Hello from %s!\\n");'):format(o.name))
	end
	vim.list_extend(lines, { "    return EXIT_SUCCESS;", "}", "" })
	return table.concat(lines, "\n")
end

local function main_src(o, header)
	return o.lang == "cpp" and cpp_main(o, header) or c_main(o, header)
end

local function gtest_src(o, header)
	return render([[
#include "%s"

#include <gtest/gtest.h>

TEST(WordCount, EmptyTextHasNoWords) {
    EXPECT_EQ(%%name%%::word_count(""), 0U);
}

TEST(WordCount, CountsWordsSeparatedByAnyWhitespace) {
    EXPECT_EQ(%%name%%::word_count("  one two\tthree\n"), 3U);
}
]], { name = o.name }):format(header)
end

-- Dependency-free tests (C projects, and C++ projects built with Make)
local function check_header(o)
	if o.lang == "cpp" then
		return [[
#pragma once

#include <cstdio>

// Tiny test helper: CHECK(cond) records failures, check_report() returns the exit code.
static int check_failures = 0;

#define CHECK(cond)                                                                   \
    do {                                                                              \
        if (!(cond)) {                                                                \
            std::fprintf(stderr, "%s:%d: CHECK failed: %s\n", __FILE__, __LINE__, #cond); \
            ++check_failures;                                                         \
        }                                                                             \
    } while (0)

inline int check_report() {
    if (check_failures != 0) {
        std::fprintf(stderr, "%d check(s) failed\n", check_failures);
        return 1;
    }
    std::puts("all checks passed");
    return 0;
}
]]
	end
	return [[
#ifndef CHECK_H
#define CHECK_H

#include <stdio.h>

/* Tiny test helper: CHECK(cond) records failures, check_report() returns the exit code. */
static int check_failures = 0;

#define CHECK(cond)                                                                  \
    do {                                                                             \
        if (!(cond)) {                                                               \
            fprintf(stderr, "%s:%d: CHECK failed: %s\n", __FILE__, __LINE__, #cond); \
            ++check_failures;                                                        \
        }                                                                            \
    } while (0)

static inline int check_report(void) {
    if (check_failures != 0) {
        fprintf(stderr, "%d check(s) failed\n", check_failures);
        return 1;
    }
    puts("all checks passed");
    return 0;
}

#endif /* CHECK_H */
]]
end

local function check_test_src(o, header)
	local h = o.lang == "cpp" and "check.hpp" or "check.h"
	local fn = o.lang == "cpp" and (o.name .. "::word_count") or (o.name .. "_word_count")
	local sig = o.lang == "cpp" and "int main() {" or "int main(void) {"
	return table.concat({
		('#include "%s"'):format(h),
		('#include "%s"'):format(header),
		"",
		sig,
		("    CHECK(%s(\"\") == 0);"):format(fn),
		("    CHECK(%s(\"  one two\\tthree\\n\") == 3);"):format(fn),
		"    return check_report();",
		"}",
		"",
	}, "\n")
end

local function bench_src(o, header)
	return render([[
#include "%s"

#include <benchmark/benchmark.h>

#include <cstdint>
#include <string>

static void BM_WordCount(benchmark::State& state) {
    std::string text;
    for (std::int64_t i = 0; i < state.range(0); ++i) {
        text += "word ";
    }
    for (auto _ : state) {
        benchmark::DoNotOptimize(%%name%%::word_count(text));
    }
    state.SetBytesProcessed(state.iterations() * static_cast<std::int64_t>(text.size()));
}
BENCHMARK(BM_WordCount)->Range(8, 8 << 10);
]], { name = o.name }):format(header)
end


local function clang_format(o)
	return render([[
BasedOnStyle: LLVM
IndentWidth: 4
ColumnLimit: 100
AllowShortFunctionsOnASingleLine: Empty
PointerAlignment: %%ptr%%
IncludeBlocks: Regroup
SortIncludes: CaseSensitive
]], { ptr = o.lang == "cpp" and "Left" or "Right" })
end

local CLANG_TIDY = [[
# Bug-finding checks first; style checks are kept to the ones that catch real mistakes.
Checks: >
  -*,
  bugprone-*,
  cert-err33-c,
  cert-err34-c,
  cert-msc50-cpp,
  cert-msc51-cpp,
  clang-analyzer-*,
  concurrency-*,
  cppcoreguidelines-*,
  misc-*,
  modernize-*,
  performance-*,
  portability-*,
  readability-*,
  -bugprone-easily-swappable-parameters,
  -cppcoreguidelines-avoid-do-while,
  -cppcoreguidelines-avoid-magic-numbers,
  -cppcoreguidelines-owning-memory,
  -cppcoreguidelines-pro-bounds-pointer-arithmetic,
  -cppcoreguidelines-pro-type-vararg,
  -misc-include-cleaner,
  -misc-non-private-member-variables-in-classes,
  -modernize-use-trailing-return-type,
  -portability-avoid-pragma-once,
  -readability-identifier-length,
  -readability-magic-numbers
WarningsAsErrors: ''
HeaderFilterRegex: '.*/(include|src|app)/.*'
FormatStyle: file
CheckOptions:
  readability-function-cognitive-complexity.Threshold: 25
  bugprone-exception-escape.CheckMain: false
]]

-- Test macros (gtest TEST, CHECK) trip a few guideline checks by design
local CLANG_TIDY_TESTS = [[
InheritParentConfig: true
Checks: >
  -cppcoreguidelines-avoid-non-const-global-variables,
  -cppcoreguidelines-macro-usage,
  -cert-err58-cpp,
  -readability-function-cognitive-complexity
]]

local GITIGNORE = [[
build/
builddir/
.cache/
compile_commands.json
CMakeUserPresets.json
*.gcov
]]

local EDITORCONFIG = [[
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 4

[{Makefile,*.mk}]
indent_style = tab

[*.{json,yml,yaml}]
indent_size = 2
]]


local function cmake_header(v, desc)
	return render([[
cmake_minimum_required(VERSION 3.28)
project(%%name%%
    VERSION 0.1.0
    DESCRIPTION "%%desc%%"
    LANGUAGES %%LANG%%)
]], vim.tbl_extend("force", v, { desc = desc }))
end

local WARN_INLINE = [[
target_compile_options(%%t%% PRIVATE
    "$<$<%%LANG%%_COMPILER_ID:GNU,Clang,AppleClang>:-Wall;-Wextra;-Wpedantic;-Wshadow;-Wconversion>"
    "$<$<%%LANG%%_COMPILER_ID:MSVC>:/W4>")
]]

local function minimal_cmake(o, v, files)
	local out = { cmake_header(v, "A small " .. (o.lang == "cpp" and "C++" or "C") .. " project") }
	table.insert(out, render([[

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_%%LANG%%_EXTENSIONS OFF)%%noscan%%
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/bin")
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
endif()
]], vim.tbl_extend("force", v, { noscan = o.lang == "cpp" and "\nset(CMAKE_CXX_SCAN_FOR_MODULES OFF) # no C++20 modules here" or "" })))
	local function warn(t)
		return render(WARN_INLINE, vim.tbl_extend("force", v, { t = t }))
	end
	local hdr = o.name .. "/" .. o.name .. "." .. v.hext
	if o.kind == "app" then
		table.insert(out, render("\nadd_executable(%%name%% src/main.%%ext%%)\ntarget_compile_features(%%name%% PRIVATE %%feature%%)\n", v) .. warn(o.name))
		files["src/main." .. v.ext] = main_src(o)
	elseif o.kind == "header" then
		table.insert(out, render([[

add_library(%%name%% INTERFACE)
add_library(%%name%%::%%name%% ALIAS %%name%%)
target_include_directories(%%name%% INTERFACE "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>")
target_compile_features(%%name%% INTERFACE %%feature%%)

if(PROJECT_IS_TOP_LEVEL)
    add_executable(%%name%%_example examples/basic.%%ext%%)
    target_link_libraries(%%name%%_example PRIVATE %%name%%::%%name%%)
]], v) .. warn(o.name .. "_example"):gsub("\n(.)", "\n    %1"):gsub("^", "    ") .. "endif()\n")
		files["include/" .. hdr] = o.lang == "cpp" and cpp_header(o, true) or c_header(o, true)
		files["examples/basic." .. v.ext] = main_src(o, hdr)
	else
		-- lib and app_lib share the shape: a library + one program using it
		local lib = o.kind == "lib" and o.name or (o.name .. "_lib")
		local alias = o.kind == "lib" and (o.name .. "::" .. o.name) or (o.name .. "::lib")
		local exe = o.kind == "lib" and (o.name .. "_example") or o.name
		local exe_src = o.kind == "lib" and ("examples/basic." .. v.ext) or ("app/main." .. v.ext)
		table.insert(out, render(([[

add_library(%s src/%%%%name%%%%.%%%%ext%%%%)
add_library(%s ALIAS %s)
target_include_directories(%s PUBLIC "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>")
target_compile_features(%s PUBLIC %%%%feature%%%%)
]]):format(lib, alias, lib, lib, lib), v) .. warn(lib))
		table.insert(out, ("\nadd_executable(%s %s)\ntarget_link_libraries(%s PRIVATE %s)\n"):format(exe, exe_src, exe, alias) .. warn(exe))
		files["include/" .. hdr] = o.lang == "cpp" and cpp_header(o) or c_header(o)
		files["src/" .. o.name .. "." .. v.ext] = o.lang == "cpp" and cpp_source(o, hdr) or c_source(o, hdr)
		files[exe_src] = main_src(o, hdr)
	end
	files["CMakeLists.txt"] = table.concat(out)
end

local WARNINGS_CMAKE = [[
# %%name%%_set_warnings(<target>): strict warnings for GCC, Clang and MSVC.
# Turn on %%NAME%%_WARNINGS_AS_ERRORS (the ci preset does) to fail on any warning.
option(%%NAME%%_WARNINGS_AS_ERRORS "Treat warnings as errors" OFF)

function(%%name%%_set_warnings target)
    set(common -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wcast-align -Wnull-dereference
        -Wdouble-promotion -Wformat=2 -Wimplicit-fallthrough)
    set(cxx_only -Wnon-virtual-dtor -Woverloaded-virtual -Wold-style-cast)
    set(c_only -Wstrict-prototypes -Wmissing-prototypes -Wvla)
    set(gcc_only -Wduplicated-cond -Wlogical-op)
    if(%%NAME%%_WARNINGS_AS_ERRORS)
        list(APPEND common -Werror)
    endif()
    target_compile_options(${target} PRIVATE
        "$<$<COMPILE_LANG_AND_ID:CXX,GNU,Clang,AppleClang>:${common};${cxx_only}>"
        "$<$<COMPILE_LANG_AND_ID:C,GNU,Clang,AppleClang>:${common};${c_only}>"
        "$<$<COMPILE_LANG_AND_ID:CXX,GNU>:${gcc_only}>"
        "$<$<COMPILE_LANG_AND_ID:C,GNU>:${gcc_only}>"
        "$<$<COMPILE_LANG_AND_ID:CXX,MSVC>:/W4;/permissive->"
        "$<$<COMPILE_LANG_AND_ID:C,MSVC>:/W4>")
endfunction()
]]

local SANITIZERS_CMAKE = [[
# %%name%%_enable_sanitizers(<target>): builds with the sanitizers listed in %%NAME%%_SANITIZERS,
# e.g. "address;undefined" (asan preset) or "thread" (tsan preset). ASan and TSan can't be combined.
set(%%NAME%%_SANITIZERS "" CACHE STRING "Sanitizers to enable, e.g. address;undefined or thread")

function(%%name%%_enable_sanitizers target)
    if(NOT %%NAME%%_SANITIZERS OR MSVC)
        return()
    endif()
    list(JOIN %%NAME%%_SANITIZERS "," list)
    target_compile_options(${target} PRIVATE -fsanitize=${list} -fno-omit-frame-pointer -fno-sanitize-recover=all)
    target_link_options(${target} PRIVATE -fsanitize=${list})
endfunction()
]]

local HARDENING_CMAKE = [[
# %%name%%_enable_hardening(<target>): stack protection, FORTIFY_SOURCE (optimized builds),
# control-flow protection, full RELRO and cheap standard-library assertions.
option(%%NAME%%_ENABLE_HARDENING "Hardening compiler and linker flags" ON)

function(%%name%%_enable_hardening target)
    if(NOT %%NAME%%_ENABLE_HARDENING OR MSVC)
        return()
    endif()
    target_compile_options(${target} PRIVATE
        -fstack-protector-strong
        -fstack-clash-protection
        "$<$<NOT:$<CONFIG:Debug>>:-U_FORTIFY_SOURCE;-D_FORTIFY_SOURCE=3>")
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
        target_compile_options(${target} PRIVATE -fcf-protection=full)
    endif()
    target_compile_definitions(${target} PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:_GLIBCXX_ASSERTIONS>")
    get_target_property(type ${target} TYPE)
    if(type STREQUAL "EXECUTABLE")
        target_link_options(${target} PRIVATE -Wl,-z,relro,-z,now)
    endif()
endfunction()
]]

local TOOLING_CMAKE = [[
# Build speed and analysis switches. Presets turn these on (tidy, coverage ...).
option(%%NAME%%_ENABLE_CCACHE "Use ccache when installed" ON)
option(%%NAME%%_ENABLE_LTO "Link-time optimization for Release builds" ON)
option(%%NAME%%_ENABLE_CLANG_TIDY "Run clang-tidy while compiling" OFF)
option(%%NAME%%_ENABLE_COVERAGE "Instrument for code coverage (gcov/gcovr)" OFF)
set(%%NAME%%_LINKER "auto" CACHE STRING "Linker: auto (mold, else lld with Clang), mold, lld, default")

if(%%NAME%%_ENABLE_CCACHE)
    find_program(CCACHE_PROGRAM ccache)
    if(CCACHE_PROGRAM)
        set(CMAKE_%%LANG%%_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
    endif()
endif()

if(%%NAME%%_LINKER STREQUAL "auto")
    find_program(MOLD_PROGRAM mold)
    find_program(LLD_PROGRAM ld.lld)
    if(MOLD_PROGRAM)
        set(linker mold)
    elseif(LLD_PROGRAM AND CMAKE_%%LANG%%_COMPILER_ID MATCHES "Clang")
        set(linker lld) # GCC's LTO plugin doesn't work with lld
    endif()
elseif(NOT %%NAME%%_LINKER STREQUAL "default")
    set(linker ${%%NAME%%_LINKER})
endif()
if(linker AND NOT MSVC)
    add_link_options(-fuse-ld=${linker})
endif()

if(%%NAME%%_ENABLE_LTO)
    include(CheckIPOSupported)
    check_ipo_supported(RESULT ipo_ok OUTPUT ipo_msg LANGUAGES %%LANG%%)
    if(ipo_ok)
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE ON)
    else()
        message(STATUS "LTO not available: ${ipo_msg}")
    endif()
endif()

if(%%NAME%%_ENABLE_CLANG_TIDY)
    find_program(CLANG_TIDY_PROGRAM clang-tidy REQUIRED)
endif()

if(%%NAME%%_ENABLE_COVERAGE)
    find_program(GCOVR_PROGRAM gcovr)
    if(GCOVR_PROGRAM)
        add_custom_target(coverage
            COMMAND ${CMAKE_COMMAND} -E make_directory "${PROJECT_BINARY_DIR}/coverage"
            COMMAND ${GCOVR_PROGRAM} --root "${PROJECT_SOURCE_DIR}"
                --filter "${PROJECT_SOURCE_DIR}/(src|include|app)/"
                --html-details "${PROJECT_BINARY_DIR}/coverage/index.html" --print-summary
            WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
            COMMENT "Coverage report: ${PROJECT_BINARY_DIR}/coverage/index.html")
    else()
        message(STATUS "gcovr not found: run the tests, then use gcov or install gcovr for a report")
    endif()
endif()

# Applied per target so fetched dependencies (GoogleTest ...) aren't analysed or instrumented
function(%%name%%_enable_tooling target)
    if(%%NAME%%_ENABLE_CLANG_TIDY)
        set_target_properties(${target} PROPERTIES %%LANG%%_CLANG_TIDY "${CLANG_TIDY_PROGRAM}")
    endif()
    if(%%NAME%%_ENABLE_COVERAGE AND NOT MSVC)
        target_compile_options(${target} PRIVATE --coverage -O0 -g)
        target_link_options(${target} PRIVATE --coverage)
    endif()
endfunction()
]]

local INSTALL_CMAKE = [[
# Installs the library with a CMake package, so other projects can use:
#   find_package(%%name%% CONFIG REQUIRED)
#   target_link_libraries(app PRIVATE %%name%%::%%name%%)
include(CMakePackageConfigHelpers)

install(TARGETS %%name%%
    EXPORT %%name%%Targets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
install(DIRECTORY "${PROJECT_SOURCE_DIR}/include/" DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})%%generated%%
install(EXPORT %%name%%Targets
    NAMESPACE %%name%%::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/%%name%%)

configure_package_config_file("${PROJECT_SOURCE_DIR}/cmake/%%name%%Config.cmake.in"
    "${PROJECT_BINARY_DIR}/%%name%%Config.cmake"
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/%%name%%)
write_basic_package_version_file("${PROJECT_BINARY_DIR}/%%name%%ConfigVersion.cmake"
    COMPATIBILITY SameMajorVersion%%archindep%%)
install(FILES
    "${PROJECT_BINARY_DIR}/%%name%%Config.cmake"
    "${PROJECT_BINARY_DIR}/%%name%%ConfigVersion.cmake"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/%%name%%)
]]

local CONFIG_IN = [[
@PACKAGE_INIT@

include("${CMAKE_CURRENT_LIST_DIR}/%%name%%Targets.cmake")
check_required_components(%%name%%)
]]

local DOCS_CMAKE = [[
# `cmake --build --preset <preset> --target docs` -> <build>/docs/html/index.html
find_package(Doxygen)
if(NOT DOXYGEN_FOUND)
    message(STATUS "Doxygen not found: no docs target")
    return()
endif()
set(DOXYGEN_EXTRACT_ALL YES)
set(DOXYGEN_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/docs")
set(DOXYGEN_USE_MDFILE_AS_MAINPAGE "${PROJECT_SOURCE_DIR}/README.md")
set(sources "${PROJECT_SOURCE_DIR}/README.md" "${PROJECT_SOURCE_DIR}/include")
if(EXISTS "${PROJECT_SOURCE_DIR}/src")
    list(APPEND sources "${PROJECT_SOURCE_DIR}/src")
endif()
doxygen_add_docs(docs ${sources} COMMENT "API documentation")
]]

local PACKAGING_CMAKE = [[
# `cpack --preset release` from the build dir (or cmake --build ... --target package)
set(CPACK_PACKAGE_VENDOR "%%name%%")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_DESCRIPTION}")
set(CPACK_GENERATOR TGZ)
set(CPACK_SOURCE_GENERATOR TGZ)
set(CPACK_SOURCE_IGNORE_FILES "/build/;/\\.git/;/\\.cache/")
include(CPack)
]]

local function version_in(o)
	if o.lang == "cpp" then
		return render([[
#pragma once

#define %%NAME%%_VERSION "@PROJECT_VERSION@"
#define %%NAME%%_VERSION_MAJOR @PROJECT_VERSION_MAJOR@
#define %%NAME%%_VERSION_MINOR @PROJECT_VERSION_MINOR@
#define %%NAME%%_VERSION_PATCH @PROJECT_VERSION_PATCH@
]], { NAME = o.name:upper() })
	end
	return render([[
#ifndef %%NAME%%_VERSION_H
#define %%NAME%%_VERSION_H

#define %%NAME%%_VERSION "@PROJECT_VERSION@"
#define %%NAME%%_VERSION_MAJOR @PROJECT_VERSION_MAJOR@
#define %%NAME%%_VERSION_MINOR @PROJECT_VERSION_MINOR@
#define %%NAME%%_VERSION_PATCH @PROJECT_VERSION_PATCH@

#endif /* %%NAME%%_VERSION_H */
]], { NAME = o.name:upper() })
end

-- CMakePresets.json, written by hand so it stays readable
local function presets_json(o, v, robust)
	local NAME = v.NAME
	local list = {
		{ "debug", "Debug", "Debug" },
		{ "release", "Release", "Release" },
		{ "asan", "Debug + ASan/UBSan", "Debug", { [NAME .. "_SANITIZERS"] = "address;undefined" } },
	}
	if robust then
		vim.list_extend(list, {
			{ "relwithdebinfo", "Release with debug info", "RelWithDebInfo" },
			{ "tsan", "Debug + ThreadSanitizer", "Debug", { [NAME .. "_SANITIZERS"] = "thread" } },
			{ "coverage", "Coverage (gcov)", "Debug", { [NAME .. "_ENABLE_COVERAGE"] = "ON" } },
			{ "tidy", "clang-tidy while compiling", "Debug", { [NAME .. "_ENABLE_CLANG_TIDY"] = "ON" } },
			{
				"profile", "Profiling (perf): optimized + frame pointers", "RelWithDebInfo",
				{ ["CMAKE_" .. v.LANG .. "_FLAGS"] = "-fno-omit-frame-pointer" },
			},
			{
				"native", "Benchmarking: -O3 -march=native", "Release",
				vim.tbl_extend("force", { ["CMAKE_" .. v.LANG .. "_FLAGS"] = "-march=native" },
					o.lang == "cpp" and o.std >= 17 and { [NAME .. "_BUILD_BENCHMARKS"] = "ON" } or {}),
			},
			{
				"ci", "CI: ASan/UBSan + warnings as errors", "Debug",
				{ [NAME .. "_SANITIZERS"] = "address;undefined", [NAME .. "_WARNINGS_AS_ERRORS"] = "ON" },
			},
		})
	end
	local function kv(t, indent)
		local keys = vim.tbl_keys(t)
		table.sort(keys)
		local out = {}
		for _, k in ipairs(keys) do
			table.insert(out, ("%s%q: %q"):format(indent, k, t[k]))
		end
		return table.concat(out, ",\n")
	end
	local configure, build, test = {}, {}, {}
	table.insert(configure, [[
    {
      "name": "base",
      "hidden": true,
      "generator": "Ninja",
      "binaryDir": "${sourceDir}/build/${presetName}",
      "cacheVariables": {
        "CMAKE_EXPORT_COMPILE_COMMANDS": "ON"
      }
    }]])
	for _, p in ipairs(list) do
		local cache = vim.tbl_extend("force", { CMAKE_BUILD_TYPE = p[3] }, p[4] or {})
		table.insert(configure, ([[
    {
      "name": %q,
      "displayName": %q,
      "inherits": "base",
      "cacheVariables": {
%s
      }
    }]]):format(p[1], p[2], kv(cache, "        ")))
		table.insert(build, ('    { "name": %q, "configurePreset": %q }'):format(p[1], p[1]))
		table.insert(test, ([[
    {
      "name": %q,
      "configurePreset": %q,
      "output": { "outputOnFailure": true },
      "execution": { "noTestsAction": "error", "jobs": 0 }
    }]]):format(p[1], p[1]))
	end
	local parts = {
		"{",
		'  "version": 6,',
		'  "cmakeMinimumRequired": { "major": 3, "minor": 28, "patch": 0 },',
		'  "configurePresets": [',
		table.concat(configure, ",\n"),
		"  ],",
		'  "buildPresets": [',
		table.concat(build, ",\n"),
		"  ],",
		'  "testPresets": [',
		table.concat(test, ",\n"),
		robust and "  ]," or "  ]",
	}
	if robust then
		vim.list_extend(parts, {
			'  "workflowPresets": [',
			"    {",
			'      "name": "ci",',
			'      "steps": [',
			'        { "type": "configure", "name": "ci" },',
			'        { "type": "build", "name": "ci" },',
			'        { "type": "test", "name": "ci" }',
			"      ]",
			"    }",
			"  ]",
		})
	end
	table.insert(parts, "}")
	return table.concat(parts, "\n") .. "\n"
end

local CI_YML = [[
name: CI

on:
  push:
  pull_request:

jobs:
  build:
    runs-on: ubuntu-24.04
    strategy:
      fail-fast: false
      matrix:
        compiler:
          - { cc: gcc-14, cxx: g++-14 }
          - { cc: clang-18, cxx: clang++-18 }
        preset: [ci, release]
    env:
      CC: ${{ matrix.compiler.cc }}
      CXX: ${{ matrix.compiler.cxx }}
    steps:
      - uses: actions/checkout@v4
      - name: Install tools
        run: sudo apt-get update && sudo apt-get install -y ninja-build g++-14 clang-18
      - name: Configure
        run: cmake --preset ${{ matrix.preset }}
      - name: Build
        run: cmake --build --preset ${{ matrix.preset }}
      - name: Test
        run: ctest --preset ${{ matrix.preset }}
]]

local function cmake_project(o, v, files)
	local robust = o.tier == "robust"
	local cpp = o.lang == "cpp"
	local hdr = o.name .. "/" .. o.name .. "." .. v.hext
	local is_lib = o.kind == "lib" or o.kind == "header"

	local root = { cmake_header(v, o.name) }
	table.insert(root, render([[

if(PROJECT_SOURCE_DIR STREQUAL PROJECT_BINARY_DIR)
    message(FATAL_ERROR "In-source builds are not allowed: cmake --preset debug")
endif()

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
set(CMAKE_%%LANG%%_EXTENSIONS OFF)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/bin")
include(GNUInstallDirs)
]], v))
	if cpp then
		table.insert(root, "# No C++20 modules here: skip module scanning (faster, and clang-tidy can't read GCC's scan flags)\nset(CMAKE_CXX_SCAN_FOR_MODULES OFF)\n")
	end
	if robust then
		table.insert(root, "include(Tooling)\ninclude(Hardening)\n")
	end
	table.insert(root, "include(Warnings)\ninclude(Sanitizers)\n")
	table.insert(root, render([[

# Every target of this project gets the same warnings and checks
function(%%name%%_setup_target target)
    %%name%%_set_warnings(${target})
    %%name%%_enable_sanitizers(${target})%s
endfunction()
]], v):format(robust and render("\n    %%name%%_enable_hardening(${target})\n    %%name%%_enable_tooling(${target})", v) or ""))
	if robust then
		table.insert(root, render([[

configure_file("${PROJECT_SOURCE_DIR}/cmake/version.%%hext%%.in"
    "${PROJECT_BINARY_DIR}/include/%%name%%/version.%%hext%%" @ONLY)
]], v))
		files["cmake/version." .. v.hext .. ".in"] = version_in(o)
	end

	local gen_inc = robust and '\n    "$<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>"' or ""
	if o.kind == "header" then
		table.insert(root, render([[

add_library(%%name%% INTERFACE)
add_library(%%name%%::%%name%% ALIAS %%name%%)
target_include_directories(%%name%% INTERFACE
    "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>"%s
    "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>")
target_compile_features(%%name%% INTERFACE %%feature%%)
]], v):format(gen_inc))
		files["include/" .. hdr] = cpp and cpp_header(o, true) or c_header(o, true)
	else
		table.insert(root, "\nadd_subdirectory(src)\n")
		local lib = o.kind == "lib" and o.name or (o.name .. "_lib")
		local src_cmake
		if o.kind == "app" then
			-- the program's code, minus main, as an object library the tests reuse
			src_cmake = render([[
# The program's code except main() is an object library, so the tests can link it
add_library(%%name%%_core OBJECT %%name%%.%%ext%%)
target_include_directories(%%name%%_core PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}"%%geninc%%)
target_compile_features(%%name%%_core PUBLIC %%feature%%)
%%name%%_setup_target(%%name%%_core)

add_executable(%%name%% main.%%ext%%)
target_link_libraries(%%name%% PRIVATE %%name%%_core)
%%name%%_setup_target(%%name%%)
]], vim.tbl_extend("force", v, { geninc = robust and ' "${PROJECT_BINARY_DIR}/include"' or "" }))
			if robust then
				src_cmake = src_cmake .. render("\ninstall(TARGETS %%name%% RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})\n", v)
			end
			local local_hdr = o.name .. "." .. v.hext
			files["src/" .. local_hdr] = cpp and cpp_header(o) or c_header(o)
			files["src/" .. o.name .. "." .. v.ext] = cpp and cpp_source(o, local_hdr) or c_source(o, local_hdr)
			files["src/main." .. v.ext] = main_src(o, local_hdr)
			v.target = o.name .. "_core"
		else
			local export = robust and o.kind == "lib"
			src_cmake = render(([[
add_library(%s %%%%name%%%%.%%%%ext%%%%)
add_library(%s ALIAS %s)
target_include_directories(%s PUBLIC
    "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>"%s
    "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>")
target_compile_features(%s PUBLIC %%%%feature%%%%)
set_target_properties(%s PROPERTIES VERSION ${PROJECT_VERSION} SOVERSION ${PROJECT_VERSION_MAJOR})
%%%%name%%%%_setup_target(%s)
]]):format(lib, v.target, lib, lib, gen_inc, lib, lib, lib), v)
			if export then
				src_cmake = src_cmake .. render([[

# Only symbols marked %%NAME%%_EXPORT are visible from the shared library
set_target_properties(%%name%% PROPERTIES %%LANG%%_VISIBILITY_PRESET hidden VISIBILITY_INLINES_HIDDEN ON)
include(GenerateExportHeader)
generate_export_header(%%name%% EXPORT_FILE_NAME "${PROJECT_BINARY_DIR}/include/%%name%%/export.%%hext%%")
if(NOT BUILD_SHARED_LIBS)
    target_compile_definitions(%%name%% PUBLIC %%NAME%%_STATIC_DEFINE)
endif()
]], v)
			end
			files["include/" .. hdr] = cpp and cpp_header(o, false, export) or c_header(o, false, export)
			files["src/" .. o.name .. "." .. v.ext] = cpp and cpp_source(o, hdr) or c_source(o, hdr)
		end
		files["src/CMakeLists.txt"] = src_cmake
		if o.kind == "app_lib" then
			table.insert(root, "add_subdirectory(app)\n")
			files["app/CMakeLists.txt"] = render([[
add_executable(%%name%% main.%%ext%%)
target_link_libraries(%%name%% PRIVATE %%name%%::lib)
%%name%%_setup_target(%%name%%)
]], v) .. (robust and render("\ninstall(TARGETS %%name%% RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})\n", v) or "")
			files["app/main." .. v.ext] = main_src(o, hdr)
		end
	end

	-- tests, examples, benchmarks, docs: only when this is the top-level project
	local top = { "\nif(PROJECT_IS_TOP_LEVEL)" }
	table.insert(top, render([[
    option(%%NAME%%_BUILD_TESTS "Build the tests" ON)
    if(%%NAME%%_BUILD_TESTS)
        enable_testing()
        add_subdirectory(tests)
    endif()]], v))
	if is_lib then
		table.insert(top, render([[
    option(%%NAME%%_BUILD_EXAMPLES "Build the examples" ON)
    if(%%NAME%%_BUILD_EXAMPLES)
        add_subdirectory(examples)
    endif()]], v))
		files["examples/CMakeLists.txt"] = render([[
add_executable(%%name%%_example basic.%%ext%%)
target_link_libraries(%%name%%_example PRIVATE %%name%%::%%name%%)
%%name%%_setup_target(%%name%%_example)
]], v)
		files["examples/basic." .. v.ext] = main_src(o, hdr)
	end
	local benches = robust and cpp and o.std >= 17
	if benches then
		table.insert(top, render([[
    option(%%NAME%%_BUILD_BENCHMARKS "Build the benchmarks (fetches Google Benchmark)" OFF)
    if(%%NAME%%_BUILD_BENCHMARKS)
        add_subdirectory(benchmarks)
    endif()]], v))
		files["benchmarks/CMakeLists.txt"] = render([[
include(FetchContent)
FetchContent_Declare(benchmark
    GIT_REPOSITORY https://github.com/google/benchmark.git
    GIT_TAG %%benchmark%%
    GIT_SHALLOW TRUE
    FIND_PACKAGE_ARGS NAMES benchmark)
set(BENCHMARK_ENABLE_TESTING OFF CACHE BOOL "" FORCE)
set(BENCHMARK_ENABLE_INSTALL OFF CACHE BOOL "" FORCE)
set(BENCHMARK_ENABLE_WERROR OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(benchmark)

# Run with the native preset: cmake --preset native && cmake --build --preset native
add_executable(%%name%%_bench %%name%%_bench.cpp)
target_link_libraries(%%name%%_bench PRIVATE %%target%% benchmark::benchmark_main)
]], v)
		local bench_hdr = o.kind == "app" and (o.name .. "." .. v.hext) or hdr
		files["benchmarks/" .. o.name .. "_bench.cpp"] = bench_src(o, bench_hdr)
	end
	if robust then
		table.insert(top, render([[
    option(%%NAME%%_BUILD_DOCS "Add a Doxygen 'docs' target" ON)
    if(%%NAME%%_BUILD_DOCS)
        include(Docs)
    endif()]], v))
		files["cmake/Docs.cmake"] = DOCS_CMAKE
	end
	table.insert(top, "endif()\n")
	table.insert(root, table.concat(top, "\n"))

	if is_lib then
		table.insert(root, "\ninclude(Install)\n")
		files["cmake/Install.cmake"] = render(INSTALL_CMAKE, vim.tbl_extend("force", v, {
			generated = robust and '\ninstall(DIRECTORY "${PROJECT_BINARY_DIR}/include/" DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})' or "",
			archindep = o.kind == "header" and " ARCH_INDEPENDENT" or "",
		}))
		files["cmake/" .. o.name .. "Config.cmake.in"] = render(CONFIG_IN, v)
	end
	if robust then
		table.insert(root, "include(Packaging)\n")
		files["cmake/Packaging.cmake"] = render(PACKAGING_CMAKE, v)
		files["cmake/Tooling.cmake"] = render(TOOLING_CMAKE, v)
		files["cmake/Hardening.cmake"] = render(HARDENING_CMAKE, v)
		files[".github/workflows/ci.yml"] = CI_YML
		files[".editorconfig"] = EDITORCONFIG
	end
	files["cmake/Warnings.cmake"] = render(WARNINGS_CMAKE, v)
	files["cmake/Sanitizers.cmake"] = render(SANITIZERS_CMAKE, v)
	files["CMakeLists.txt"] = table.concat(root)
	files["CMakePresets.json"] = presets_json(o, v, robust)

	-- tests
	local test_hdr = o.kind == "app" and (o.name .. "." .. v.hext) or hdr
	if cpp then
		files["tests/CMakeLists.txt"] = render([[
include(FetchContent)
FetchContent_Declare(googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG %%gtest%%
    GIT_SHALLOW TRUE
    FIND_PACKAGE_ARGS NAMES GTest)
set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

add_executable(%%name%%_tests %%name%%_test.cpp)
target_link_libraries(%%name%%_tests PRIVATE %%target%% GTest::gtest_main GTest::gmock)
%%name%%_setup_target(%%name%%_tests)

include(GoogleTest)
gtest_discover_tests(%%name%%_tests)
]], v)
		files["tests/" .. o.name .. "_test.cpp"] = gtest_src(o, test_hdr)
	else
		files["tests/CMakeLists.txt"] = render([[
add_executable(%%name%%_tests %%name%%_test.c)
target_link_libraries(%%name%%_tests PRIVATE %%target%%)
%%name%%_setup_target(%%name%%_tests)
add_test(NAME %%name%%_tests COMMAND %%name%%_tests)
]], v)
		files["tests/check.h"] = check_header(o)
		files["tests/" .. o.name .. "_test.c"] = check_test_src(o, test_hdr)
	end
	files[".clang-tidy"] = CLANG_TIDY
	files["tests/.clang-tidy"] = CLANG_TIDY_TESTS
end


local function makefile(o, v, files)
	local cpp = o.lang == "cpp"
	local hdr = o.name .. "/" .. o.name .. "." .. v.hext
	local mid = o.tier ~= "minimal"
	local extra = cpp and " -Wnon-virtual-dtor -Woverloaded-virtual -Wold-style-cast" or " -Wstrict-prototypes -Wvla"
	local out = { render([[
# %%name%%: `make help` lists the targets. MODE=debug (default), release or asan.
%%CC%% ?= %%compiler%%
STD ?= %%stdflag%%
MODE ?= debug
BUILD := build/$(MODE)

CPPFLAGS := -Iinclude -MMD -MP
%%FLAGS%% := -std=$(STD) -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wformat=2%s
LDFLAGS :=

ifeq ($(MODE),release)
  %%FLAGS%% += -O2 -DNDEBUG
else ifeq ($(MODE),asan)
  %%FLAGS%% += -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer
  LDFLAGS += -fsanitize=address,undefined
else
  %%FLAGS%% += -O0 -g%s
endif

objects = $(patsubst %%.%%ext%%,$(BUILD)/%%.o,$(wildcard $(1)/*.%%ext%%))
]], v):format(extra, cpp and " -D_GLIBCXX_ASSERTIONS" or "") }

	local targets, phony = {}, { "all", "clean", "help" }
	local all
	if o.kind == "app" then
		if mid then
			table.insert(out, render([[
MAIN_OBJ := $(BUILD)/src/main.o
CORE_OBJS := $(filter-out $(MAIN_OBJ),$(call objects,src))
TEST_OBJS := $(call objects,tests)
APP := $(BUILD)/%%name%%
TESTS := $(BUILD)/%%name%%_tests
DEPS := $(CORE_OBJS:.o=.d) $(MAIN_OBJ:.o=.d) $(TEST_OBJS:.o=.d)
]], v))
			table.insert(targets, render([[
$(APP): $(MAIN_OBJ) $(CORE_OBJS)
	$(%%CC%%) $^ $(LDFLAGS) -o $@

$(TESTS): $(TEST_OBJS) $(CORE_OBJS)
	$(%%CC%%) $^ $(LDFLAGS) -o $@
]], v))
			local local_hdr = o.name .. "." .. v.hext
			files["src/" .. local_hdr] = cpp and cpp_header(o) or c_header(o)
			files["src/" .. o.name .. "." .. v.ext] = cpp and cpp_source(o, local_hdr) or c_source(o, local_hdr)
			files["src/main." .. v.ext] = main_src(o, local_hdr)
			files["tests/" .. o.name .. "_test." .. v.ext] = check_test_src(o, "../src/" .. local_hdr)
		else
			table.insert(out, render("OBJS := $(call objects,src)\nAPP := $(BUILD)/%%name%%\nDEPS := $(OBJS:.o=.d)\n", v))
			table.insert(targets, render("$(APP): $(OBJS)\n\t$(%%CC%%) $^ $(LDFLAGS) -o $@\n", v))
			files["src/main." .. v.ext] = main_src(o)
		end
		all = "$(APP)"
	elseif o.kind == "header" then
		table.insert(out, render([[
EXAMPLE := $(BUILD)/%%name%%_example
EXAMPLE_OBJS := $(call objects,examples)
DEPS := $(EXAMPLE_OBJS:.o=.d)
]], v))
		table.insert(targets, render("$(EXAMPLE): $(EXAMPLE_OBJS)\n\t$(%%CC%%) $^ $(LDFLAGS) -o $@\n", v))
		files["include/" .. hdr] = cpp and cpp_header(o, true) or c_header(o, true)
		files["examples/basic." .. v.ext] = main_src(o, hdr)
		all = "$(EXAMPLE)"
		if mid then
			table.insert(out, render("TESTS := $(BUILD)/%%name%%_tests\nTEST_OBJS := $(call objects,tests)\nDEPS += $(TEST_OBJS:.o=.d)\n", v))
			table.insert(targets, render("$(TESTS): $(TEST_OBJS)\n\t$(%%CC%%) $^ $(LDFLAGS) -o $@\n", v))
			files["tests/" .. o.name .. "_test." .. v.ext] = check_test_src(o, hdr)
		end
	else
		-- lib / app_lib: static library from src/, plus a program (example or app)
		local prog_dir = o.kind == "lib" and "examples" or "app"
		local prog = o.kind == "lib" and (o.name .. "_example") or o.name
		table.insert(out, render([[
LIB := $(BUILD)/lib%%name%%.a
LIB_OBJS := $(call objects,src)
PROG := $(BUILD)/%s
PROG_OBJS := $(call objects,%s)
DEPS := $(LIB_OBJS:.o=.d) $(PROG_OBJS:.o=.d)
]], v):format(prog, prog_dir))
		table.insert(targets, render([[
$(LIB): $(LIB_OBJS)
	$(AR) rcs $@ $^

$(PROG): $(PROG_OBJS) $(LIB)
	$(%%CC%%) $^ $(LDFLAGS) -o $@
]], v))
		files["include/" .. hdr] = cpp and cpp_header(o) or c_header(o)
		files["src/" .. o.name .. "." .. v.ext] = cpp and cpp_source(o, hdr) or c_source(o, hdr)
		files[prog_dir .. "/" .. (o.kind == "lib" and "basic" or "main") .. "." .. v.ext] = main_src(o, hdr)
		all = "$(LIB) $(PROG)"
		if mid then
			table.insert(out, render("TESTS := $(BUILD)/%%name%%_tests\nTEST_OBJS := $(call objects,tests)\nDEPS += $(TEST_OBJS:.o=.d)\n", v))
			table.insert(targets, render("$(TESTS): $(TEST_OBJS) $(LIB)\n\t$(%%CC%%) $^ $(LDFLAGS) -o $@\n", v))
			files["tests/" .. o.name .. "_test." .. v.ext] = check_test_src(o, hdr)
		end
	end
	if mid then
		files["tests/" .. (cpp and "check.hpp" or "check.h")] = check_header(o)
	end

	local run_target = o.kind == "app" and "$(APP)" or (o.kind == "header" and "$(EXAMPLE)" or "$(PROG)")
	table.insert(phony, "run")
	local tail = {
		"",
		".DELETE_ON_ERROR:",
		".PHONY: " .. table.concat(vim.list_extend(phony, mid and { "test" } or {}), " ") .. (o.kind == "lib" and mid and " install" or ""),
		"",
		"all: " .. all .. " ## Build everything",
		"",
		table.concat(targets, "\n"),
		render("$(BUILD)/%.o: %.%%ext%%", v),
		"\t@mkdir -p $(@D)",
		render("\t$(%%CC%%) $(CPPFLAGS) $(%%FLAGS%%) -c $< -o $@", v),
		"",
		"run: " .. run_target .. " ## Build and run",
		"\t./" .. run_target,
		"",
	}
	if mid then
		vim.list_extend(tail, { "test: $(TESTS) ## Build and run the tests", "\t./$(TESTS)", "" })
	end
	if o.kind == "lib" and mid then
		vim.list_extend(tail, {
			"PREFIX ?= /usr/local",
			"install: $(LIB) ## Install headers and library into $(PREFIX)",
			"\tinstall -d $(DESTDIR)$(PREFIX)/include $(DESTDIR)$(PREFIX)/lib",
			"\tcp -r include/. $(DESTDIR)$(PREFIX)/include/",
			"\tinstall -m 644 $(LIB) $(DESTDIR)$(PREFIX)/lib/",
			"",
		})
	end
	vim.list_extend(tail, {
		"clean: ## Remove build output",
		"\trm -rf build",
		"",
		"help: ## Show this help",
		"\t@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = \":.*?## \"}; {printf \"  %-10s %s\\n\", $$1, $$2}'",
		"",
		"-include $(DEPS)",
		"",
	})
	table.insert(out, table.concat(tail, "\n"))
	files["Makefile"] = table.concat(out, "\n")

	-- clangd reads this (no compile_commands.json needed); -x keeps .h files in the right language
	files["compile_flags.txt"] = table.concat({ "-x" .. v.xlang, "-std=" .. v.stdflag, "-Iinclude", "-Wall", "-Wextra", "-Wpedantic", "" }, "\n")
	if mid then
		files[".clang-tidy"] = CLANG_TIDY
		files["tests/.clang-tidy"] = CLANG_TIDY_TESTS
	end
end


local KIND_LABEL = {
	app = "application",
	app_lib = "application + library",
	lib = "library",
	header = "header-only library",
}

local function readme(o, v)
	local lang = o.lang == "cpp" and "C++" or "C"
	local lines = {
		"# " .. o.name,
		"",
		("A %s %s (%s, %s tier), built with %s."):format(lang .. v.std, KIND_LABEL[o.kind], v.stdflag, o.tier, o.build == "cmake" and "CMake" or "Make"),
		"",
		"## Build",
		"",
		"```sh",
	}
	if o.build == "cmake" then
		if o.tier == "minimal" then
			vim.list_extend(lines, { "cmake -S . -B build -G Ninja", "cmake --build build" })
		else
			vim.list_extend(lines, {
				"cmake --preset debug          # configure (presets: cmake --list-presets)",
				"cmake --build --preset debug  # build",
				"ctest --preset debug          # test",
			})
			if o.tier == "robust" then
				vim.list_extend(lines, {
					"cmake --workflow --preset ci  # what CI runs: ASan/UBSan + -Werror + tests",
					"cmake --preset coverage && cmake --build --preset coverage && ctest --preset coverage",
					"cmake --build --preset coverage --target coverage   # HTML report (needs gcovr)",
					"cmake --build --preset debug --target docs          # Doxygen",
				})
			end
		end
	else
		vim.list_extend(lines, { "make              # MODE=debug|release|asan", "make run" })
		if o.tier ~= "minimal" then
			table.insert(lines, "make test")
		end
	end
	vim.list_extend(lines, {
		"```",
		"",
		"In Neovim: `<leader>cb` build, `<leader>cr` run, `<leader>ct` test, `<leader>cp` preset, `F5` debug.",
		"",
	})
	return table.concat(lines, "\n")
end


function M.generate(o)
	local v = vars(o)
	local files = {}
	if o.build == "cmake" then
		if o.tier == "minimal" then
			minimal_cmake(o, v, files)
		else
			cmake_project(o, v, files)
		end
	else
		makefile(o, v, files)
	end
	files[".clang-format"] = clang_format(o)
	files[".gitignore"] = GITIGNORE
	files["README.md"] = readme(o, v)
	return files
end

local function write_files(dir, files)
	for rel, content in pairs(files) do
		local path = dir .. "/" .. rel
		vim.fn.mkdir(vim.fs.dirname(path), "p")
		local lines = vim.split(content, "\n", { plain = true })
		if lines[#lines] == "" then
			table.remove(lines)
		end
		vim.fn.writefile(lines, path)
	end
end

local function main_file(o, v)
	if o.kind == "app" then
		return "src/main." .. v.ext
	elseif o.kind == "app_lib" then
		return "app/main." .. v.ext
	elseif o.kind == "header" then
		return "include/" .. o.name .. "/" .. o.name .. "." .. v.hext
	end
	return "src/" .. o.name .. "." .. v.ext
end

function M.create(o)
	local dir = vim.fs.normalize(o.dir)
	if vim.uv.fs_stat(dir) and #vim.fn.readdir(dir) > 0 then
		return vim.notify(dir .. " already exists and isn't empty", vim.log.levels.ERROR)
	end
	local files = M.generate(o)
	write_files(dir, files)
	if vim.fn.executable("git") == 1 then
		vim.system({ "git", "init", "-q" }, { cwd = dir }):wait()
	end
	local v = vars(o)
	vim.cmd("tcd " .. vim.fn.fnameescape(dir))
	vim.cmd("edit " .. vim.fn.fnameescape(dir .. "/" .. main_file(o, v)))
	vim.notify(("Created %s (%d files)"):format(dir, vim.tbl_count(files)), vim.log.levels.INFO, { title = ":CNew" })
	if o.build == "cmake" then
		-- configure now so clangd gets compile_commands.json (fetches GoogleTest the first time)
		require("core.cc_build").configure()
	end
end


local function pick(items, prompt, cb)
	vim.ui.select(items, {
		prompt = prompt,
		format_item = function(x)
			return x.label
		end,
	}, function(choice)
		if choice then
			cb(choice.value)
		end
	end)
end

function M.new(name)
	local o = {}
	pick({
		{ label = "Application", value = "app" },
		{ label = "Application + library  (logic in a library, thin app)", value = "app_lib" },
		{ label = "Library", value = "lib" },
		{ label = "Header-only library", value = "header" },
	}, "Kind", function(kind)
		o.kind = kind
		pick({ { label = "C++", value = "cpp" }, { label = "C", value = "c" } }, "Language", function(lang)
			o.lang = lang
			pick({
				{ label = "CMake  (presets, ctest, FetchContent)", value = "cmake" },
				{ label = "Make   (plain Makefile, header deps)", value = "make" },
			}, "Build system", function(build)
				o.build = build
				local tiers = {
					{ label = "Minimal       one target, warnings, clangd ready", value = "minimal" },
					{ label = "Intermediate  + tests, presets, sanitizers, clang-tidy" .. (kind ~= "app" and kind ~= "app_lib" and ", install" or ""), value = "intermediate" },
				}
				if build == "cmake" then
					table.insert(tiers, {
						label = "Robust        + hardening, LTO, coverage/tsan/tidy/profile presets, benchmarks, docs, CPack, CI",
						value = "robust",
					})
				end
				pick(tiers, "Tier", function(tier)
					o.tier = tier
					local stds = lang == "cpp"
							and {
								{ label = "C++23", value = 23 },
								{ label = "C++26 (experimental in compilers)", value = 26 },
								{ label = "C++20", value = 20 },
								{ label = "C++17", value = 17 },
								{ label = "C++14", value = 14 },
								{ label = "C++11", value = 11 },
							}
						or {
							{ label = "C23", value = 23 },
							{ label = "C17", value = 17 },
							{ label = "C11", value = 11 },
							{ label = "C99", value = 99 },
						}
					pick(stds, "Standard", function(std)
						o.std = std
						vim.ui.input({ prompt = "Project name: ", default = name }, function(input)
							if not input or input == "" then
								return
							end
							local clean = input:lower():gsub("[^%w_]", "_"):gsub("^(%d)", "_%1")
							o.name = clean
							vim.ui.input({
								prompt = "Create in: ",
								default = vim.fn.getcwd() .. "/" .. clean,
								completion = "dir",
							}, function(dir)
								if dir and dir ~= "" then
									o.dir = vim.fn.expand(dir)
									M.create(o)
								end
							end)
						end)
					end)
				end)
			end)
		end)
	end)
end

vim.api.nvim_create_user_command("CNew", function(a)
	M.new(a.args ~= "" and a.args or nil)
end, { nargs = "?", desc = "New C/C++ project (application, library, header-only; minimal/intermediate/robust)" })

return M
