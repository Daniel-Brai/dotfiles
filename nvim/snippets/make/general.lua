-- Make snippets for any kind of project. C/C++-specific ones live in c-cpp.lua (prefix "cc").
-- Recipes start with a real TAB (Makefiles keep tabs, see after/ftplugin/make.lua).

local ls = require("luasnip")
local function S(trig, desc, body)
	return ls.parser.parse_snippet({ trig = trig, desc = desc }, body)
end

return {
	S("rule", "target: prerequisites + recipe", [=[
${1:target}: ${2:prereqs}
	${0:command}]=]),
	S("phony", ".PHONY target", [=[
.PHONY: ${1:name}
$1:
	${0:command}]=]),
	S("var", "simply expanded variable (:=)", "${1:NAME} := ${2:value}"),
	S("defvar", "overridable default (?=)", "${1:NAME} ?= ${2:value}"),
	S("ifeq", "ifeq / else / endif", [=[
ifeq (\$(${1:MODE}),${2:release})
${3}
else
${0}
endif]=]),
	S("strict", "safer Make defaults (bash, fail fast, no builtin rules)", [=[
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables --no-builtin-rules]=]),
	S("help", "self-documenting help target (## comments)", [=[
.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' \$(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", \$\$1, \$\$2}']=]),
	S("default", "default goal", ".DEFAULT_GOAL := ${1:all}"),
	S("dir", "directory as an order-only prerequisite", [=[
${1:\$(BUILD)}/${2:%}: ${3:prereq} | $1
	${0:command}

$1:
	mkdir -p \$@]=]),
	S("wild", "files from a wildcard", "${1:SRCS} := \\$(wildcard ${2:src/*.ext})"),
	S("subst", "path substitution (pattern replace)", "${1:OBJS} := \\$(${2:SRCS}:${3:src/%.ext}=${4:build/%.o})"),
	S("foreach", "$(foreach ...)", "\\$(foreach ${1:x},\\$(${2:LIST}),${3:\\$(x)})"),
	S("include", "optional include", "-include ${1:config.mk}"),
}
