local M = {}

function M.merge(...)
    local result = {}
    local tables = {...}

    for i = 1, #tables do
        for k, v in pairs(tables[i]) do
            result[k] = v
        end
    end
    return result
end


function M.keymap(keys, func, mode, options)
    mode = mode or 'n'
    options = options or {}
    vim.keymap.set(mode, keys, func, options)
end

return M
