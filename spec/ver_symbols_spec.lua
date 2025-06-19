if package.loaded.fltanim then
    package.loaded.fltanim = nil
    package.loaded['fltanim.symbols'] = nil
end

---@type number[]
local fpss = { 20, 10 }
---@type fltanim.buf_animator[]
local runners =
    vim.iter(fpss):map(require('fltanim').new_buf_animator):totable()
fpss[#fpss + 1] = 0

local buf = vim.api.nvim_create_buf(false, true)

---@type fltanim.animations[]
local vertical_symbols = {
    'dot_spinner',
    'clock_spinner',
    'box_edge_spinner',
    'box_1q_spinner',
    'box_2q_spinner',
    'box_3q_spinner',
    'box_fill',
    'vbar_fill',
}

local text = {}
for j = 0, #vertical_symbols - 1 do
    for i = 1, #fpss do
        if i == #fpss then
            text[j * #fpss + i] = ''
        else
            text[j * #fpss + i] = ('%3d  %s'):format(
                fpss[i],
                vertical_symbols[j + 1]
            )
        end
    end
end
vim.api.nvim_buf_set_lines(buf, 0, -1, true, text)

local c = 0
for j, symbol in ipairs(vertical_symbols) do
    for i, runner in ipairs(runners) do
        runner:set_animation(buf, (j - 1) * #runners + i + c, 5, symbol)
    end
    c = c + 1
end
vim.api.nvim_buf_set_lines(buf, 0, 0, true, { 'fps  animation ' })
local emns = vim.api.nvim_create_namespace('renderspec')
local emid = vim.api.nvim_buf_set_extmark(buf, emns, 0, 0, {
    virt_text = { { '  0.000 s', 'NormalFloat' } },
})
local timer = assert(vim.uv.new_timer())
local time = vim.uv.hrtime()
timer:start(
    32,
    32,
    vim.schedule_wrap(function()
        local delta = (vim.uv.hrtime() - time) * 10e-10
        vim.api.nvim_buf_set_extmark(buf, emns, 0, 0, {
            id = emid,
            virt_text = { { ('%3.3f s'):format(delta), 'NormalFloat' } },
        })
    end)
)

local wh = vim.api.nvim_buf_line_count(buf)
local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    col = (vim.o.columns - 24) / 2,
    width = 24,
    row = (vim.o.lines - wh) / 2,
    height = wh,
    style = 'minimal',
    border = 'single',
    title = 'Cell symbols',
})

vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win),
    once = true,
    callback = function()
        timer:stop()
        timer:close()
        for _, r in ipairs(runners) do
            r:stop()
        end
    end,
})
