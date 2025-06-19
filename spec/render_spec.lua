if package.loaded.fltanim then
    package.loaded.fltanim = nil
    package.loaded['fltanim.symbols'] = nil
end

local animator = require('fltanim').new_buf_animator(20)

local buf = vim.api.nvim_create_buf(false, true)

local text = {
    'Lorem ipsum dolor sit amet, consectetur',
    'adipiscing elit, sed do eiusmod tempor',
    'incididunt ut labore et dolore magna',
    'aliqua. Ut enim ad minim veniam, quis',
    'nostrud exercitation ullamco laboris',
    'nisi ut aliquip ex ea commodo consequat.',
    'Duis aute irure dolor in reprehenderit in',
    'voluptate velit esse cillum dolore eu',
    'fugiat nulla pariatur. Excepteur sint',
    'occaecat cupidatat non proident, sunt',
    'ini culpa qui officia deserunt mollit',
    'anim id est laborum.',
}

vim.api.nvim_buf_set_lines(buf, 0, -1, true, text)

local ns = vim.api.nvim_create_namespace('fltanim.spec')
local srchl = {
    'Question',
    'Title',
}
local hls = {}

---@type table<fltanim.animations|table, table>[]
local syms = {
    { 'box_fill', {} },
    { 'vbar_fill', {} },
    { 'dot_spinner', {} },
    { 'clock_spinner', {} },
    { 'box_edge_spinner', {} },
    { 'box_1q_spinner', {} },
    { 'box_2q_spinner', {} },
    { 'box_3q_spinner', {} },
    { { '_ \\ -', '- | =', '= / _' }, {} },
    { 'horizontal_indeterminate', { width = 6 } },
    { 'horizontal_fill', { width = 6 } },
    { 'horizontal_bounce', { width = 6 } },
}
local anims = {}
do
    local i = 1
    for _, sym in ipairs(syms) do
        local sname, sopts = sym[1], sym[2]
        local s = 1
        local e = #text[i]
        local p = math.random(s + 1, e - 1)

        local c = math.random(#srchl)
        vim.hl.range(buf, ns, srchl[c], { i - 1, s - 1 }, { i - 1, p - 1 })
        hls[i] = { srchl[c] }

        c = c % 2 + 1
        vim.hl.range(buf, ns, srchl[c], { i - 1, p - 1 }, { i - 1, e })
        table.insert(hls[i], srchl[c])

        anims[#anims + 1] = animator:set_animation(buf, i, p - 1, sname, sopts)
        i = i + 1
    end
end

local win = vim.api.nvim_open_win(buf, true, {
    anchor = 'NW',
    relative = 'editor',
    width = 44,
    col = (vim.o.columns / 2) - 22,
    height = #text,
    row = (vim.o.lines - #text) / 2,
    style = 'minimal',
    border = 'solid',
})

-- check that the symbol animations are removed and do not produce errors
vim.defer_fn(function()
    vim.api.nvim_buf_set_lines(buf, 0, 6, true, {})
end, 4000)

-- Check that the animations stopped
vim.defer_fn(function()
    animator:stop()
end, 8000)

-- Check that animations start again
vim.defer_fn(function()
    animator:restart()
end, 9000)

-- Check that animations are removed, and those implicitly removed do not
-- error
for i = 1, #anims do
    vim.defer_fn(function()
        animator:animation_delete(anims[i])
    end, 10000 + i * 500)
end

-- remove window..
vim.defer_fn(function()
    if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end
end, 10000 + #anims * 500 + 500)
