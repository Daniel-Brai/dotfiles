-- Box comments, laid out like the TLA+ Toolbox and tlafmt write them: the right
-- edge at column 77 whatever the indent
--
--   (***************************************************************************)
--   (* The type-correctness invariant                                          *)
--   (***************************************************************************)
--
-- <leader>cb on a line or a visual selection boxes it (wrapping long lines, and
-- turning \* line comments into box rows); on a box it unboxes back to plain text,
-- so edit and press it again to realign the right edge

local WIDTH = 77

local function is_border(line)
	return line ~= nil and line:match("^%s*%(%*+%)%s*$") ~= nil
end

local function is_row(line)
	return line ~= nil and not is_border(line) and line:match("^%s*%(%*.*%*%)%s*$") ~= nil
end

local function indent_of(line)
	return #line:match("^%s*")
end

-- The first and last line of the box around row, if row is in one
local function find_box(lines, row)
	local line = lines[row]
	local function up(from)
		local s = from
		while is_row(lines[s]) do
			s = s - 1
		end
		return is_border(lines[s]) and s or nil
	end
	local function down(from)
		local e = from
		while is_row(lines[e]) do
			e = e + 1
		end
		return is_border(lines[e]) and e or nil
	end
	if is_row(line) then
		local s, e = up(row), down(row)
		if s and e then
			return s, e
		end
	elseif is_border(line) then
		-- A bottom border has rows above it; otherwise it's the top
		if is_row(lines[row - 1]) then
			local s = up(row - 1)
			if s then
				return s, row
			end
		end
		local e = down(row + 1)
		if e then
			return row, e
		end
	end
end

-- Box rows back to plain lines at the box's indent
local function unbox(lines, s, e)
	local indent = math.huge
	for n = s, e do
		indent = math.min(indent, indent_of(lines[n]))
	end
	local out = {}
	for n = s + 1, e - 1 do
		local text = lines[n]:match("^%s*%(%*%s?(.-)%s*%*%)%s*$")
		table.insert(out, text == "" and "" or (" "):rep(indent) .. text)
	end
	return out
end

-- Splits text into lines of at most width, at spaces; a single longer word stays whole
local function wrap(text, width)
	if vim.fn.strdisplaywidth(text) <= width then
		return { text }
	end
	local out, current = {}, ""
	for word in text:gmatch("%S+") do
		if current == "" then
			current = word
		elseif vim.fn.strdisplaywidth(current .. " " .. word) <= width then
			current = current .. " " .. word
		else
			table.insert(out, current)
			current = word
		end
	end
	table.insert(out, current)
	return out
end

local function border(indent)
	return (" "):rep(indent) .. "(" .. ("*"):rep(math.max(4, WIDTH - indent - 2)) .. ")"
end

local function row(indent, text)
	local inner = math.max(20, WIDTH - indent - 6)
	local pad = math.max(0, inner - vim.fn.strdisplaywidth(text))
	return (" "):rep(indent) .. "(* " .. text .. (" "):rep(pad) .. " *)"
end

local function box(lines)
	local indent = math.huge
	for _, l in ipairs(lines) do
		if l:match("%S") then
			indent = math.min(indent, indent_of(l))
		end
	end
	if indent == math.huge then
		indent = 0
	end
	-- \* comments become box rows
	local all_line_comments = true
	for _, l in ipairs(lines) do
		if l:match("%S") and not l:match("^%s*\\%*") then
			all_line_comments = false
		end
	end
	local inner = math.max(20, WIDTH - indent - 6)
	local out = { border(indent) }
	for _, l in ipairs(lines) do
		local text = vim.trim(l)
		if all_line_comments then
			text = vim.trim((text:gsub("^\\%*", "")))
		end
		-- Keep indentation inside the comment (lists, nested points)
		local inside = l:match("%S") and (" "):rep(indent_of(l) - indent) or ""
		if all_line_comments then
			inside = ""
		end
		for _, piece in ipairs(wrap(inside .. text, inner)) do
			table.insert(out, row(indent, piece))
		end
	end
	table.insert(out, border(indent))
	return out
end

-- Toggles the box over lines s..e (1-based, inclusive) of the current buffer
local function toggle(s, e)
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local bs, be = find_box(lines, s)
	if bs and be >= e then
		vim.api.nvim_buf_set_lines(buf, bs - 1, be, false, unbox(lines, bs, be))
		vim.api.nvim_win_set_cursor(0, { bs, 0 })
		return
	end
	local boxed = box(vim.list_slice(lines, s, e))
	vim.api.nvim_buf_set_lines(buf, s - 1, e, false, boxed)
	vim.api.nvim_win_set_cursor(0, { s + 1, 0 })
end

local function map(buf)
	vim.keymap.set("n", "<leader>cb", function()
		local s = vim.api.nvim_win_get_cursor(0)[1]
		toggle(s, math.min(s + vim.v.count1 - 1, vim.api.nvim_buf_line_count(0)))
	end, { buffer = buf, desc = "TLA+: box comment (toggle)" })
	vim.keymap.set("x", "<leader>cb", function()
		local s, e = vim.fn.line("v"), vim.fn.line(".")
		if s > e then
			s, e = e, s
		end
		vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
		toggle(s, e)
	end, { buffer = buf, desc = "TLA+: box comment (toggle)" })
end

return {
	WIDTH = WIDTH,
	toggle = toggle,
	map = map,
}
