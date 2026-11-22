-- CMake snippets (target-based, modern CMake). LSP snippet syntax; \${ is a literal ${.

local ls = require("luasnip")
local function S(trig, desc, body)
	return ls.parser.parse_snippet({ trig = trig, desc = desc }, body)
end

return {
	S("cmin", "cmake_minimum_required + project", [=[
cmake_minimum_required(VERSION ${1:3.28})
project(${2:app} VERSION ${3:0.1.0} LANGUAGES ${4:CXX})

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
$0]=]),
	S("exe", "executable target", [=[
add_executable(${1:app} ${2:src/main.cpp})
target_compile_features($1 PRIVATE cxx_std_${3:23})
target_link_libraries($1 PRIVATE ${4:project_warnings})$0]=]),
	S("lib", "library target with namespaced alias", [=[
add_library(${1:core} ${2:src/core.cpp})
add_library(${3:proj}::$1 ALIAS $1)
target_include_directories($1 PUBLIC
    \$<BUILD_INTERFACE:\${CMAKE_CURRENT_SOURCE_DIR}/include>
    \$<INSTALL_INTERFACE:include>)
target_compile_features($1 PUBLIC cxx_std_${4:23})$0]=]),
	S("ilib", "header-only (INTERFACE) library", [=[
add_library(${1:core} INTERFACE)
target_include_directories($1 INTERFACE \$<BUILD_INTERFACE:\${CMAKE_CURRENT_SOURCE_DIR}/include>)
target_compile_features($1 INTERFACE cxx_std_${2:23})]=]),
	S("tsrc", "target_sources", "target_sources(${1:target} PRIVATE ${2:src/file.cpp})"),
	S("tinc", "target_include_directories", "target_include_directories(${1:target} ${2:PRIVATE} ${3:include})"),
	S("tlink", "target_link_libraries", "target_link_libraries(${1:target} ${2:PRIVATE} ${3:lib})"),
	S("tdef", "target_compile_definitions", "target_compile_definitions(${1:target} ${2:PRIVATE} ${3:NAME=1})"),
	S("topt", "target_compile_options with generator expression", "target_compile_options(${1:target} PRIVATE \\$<\\$<CXX_COMPILER_ID:GNU,Clang>:${2:-Wall}>)"),
	S("warn", "warnings interface target", [=[
add_library(${1:project_warnings} INTERFACE)
target_compile_options($1 INTERFACE
    \$<\$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall -Wextra -Wpedantic -Wshadow -Wconversion>
    \$<\$<CXX_COMPILER_ID:MSVC>:/W4 /permissive->)]=]),
	S("fetch", "FetchContent dependency (prefers installed package)", [=[
include(FetchContent)
FetchContent_Declare(${1:name}
    GIT_REPOSITORY ${2:https://github.com/org/repo.git}
    GIT_TAG ${3:v1.0.0}
    GIT_SHALLOW TRUE
    FIND_PACKAGE_ARGS${4: NAMES Pkg})
FetchContent_MakeAvailable($1)]=]),
	S("gtest", "GoogleTest tests directory", [=[
include(FetchContent)
FetchContent_Declare(googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG v1.18.0
    GIT_SHALLOW TRUE
    FIND_PACKAGE_ARGS NAMES GTest)
set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

add_executable(${1:unit_tests} ${2:test_main.cpp})
target_link_libraries($1 PRIVATE ${3:core} GTest::gtest_main GTest::gmock)
include(GoogleTest)
gtest_discover_tests($1)]=]),
	S("test", "add_test", "add_test(NAME ${1:name} COMMAND ${2:target})"),
	S("opt", "option", "option(${1:ENABLE_X} \"${2:Description}\" ${3:OFF})"),
	S("find", "find_package REQUIRED", "find_package(${1:Threads} REQUIRED)"),
	S("sub", "add_subdirectory", "add_subdirectory(${1:src})"),
	S("if", "if / endif", [=[
if(${1:condition})
    $0
endif()]=]),
	S("foreach", "foreach", [=[
foreach(${1:item} IN LISTS ${2:list})
    $0
endforeach()]=]),
	S("func", "function", [=[
function(${1:name} ${2:target})
    $0
endfunction()]=]),
	S("msg", "message", "message(${1:STATUS} \"${2:text}\")"),
	S("san", "sanitizer option", [=[
option(${1:ENABLE_SANITIZERS} "Build with ASan + UBSan" OFF)
if($1)
    add_compile_options(-fsanitize=address,undefined -fno-omit-frame-pointer)
    add_link_options(-fsanitize=address,undefined)
endif()]=]),
	S("ccache", "use ccache when installed", [=[
find_program(CCACHE ccache)
if(CCACHE)
    set(CMAKE_CXX_COMPILER_LAUNCHER \${CCACHE})
endif()]=]),
	S("ipo", "LTO when supported", [=[
include(CheckIPOSupported)
check_ipo_supported(RESULT ipo_ok OUTPUT ipo_msg)
if(ipo_ok)
    set_property(TARGET ${1:app} PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE)
endif()]=]),
	S("modules", "C++20 modules file set (CMake 3.28+)", [=[
target_sources(${1:core} PUBLIC FILE_SET CXX_MODULES FILES ${2:src/core.cppm})]=]),
	S("install", "install a target", [=[
include(GNUInstallDirs)
install(TARGETS ${1:app}
    EXPORT ${2:$1}Targets
    RUNTIME DESTINATION \${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION \${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION \${CMAKE_INSTALL_LIBDIR})]=]),
	S("nosrc", "refuse in-source builds", [=[
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
    message(FATAL_ERROR "In-source builds are not allowed; use: cmake --preset debug")
endif()]=]),
}
