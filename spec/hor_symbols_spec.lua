if package.loaded.fltanim then
    package.loaded.fltanim = nil
    package.loaded['fltanim.symbols'] = nil
end

local fps = { 60, 30, 20, 10 }
local width = 6
local duration = nil -- default duration targets 1s when width is 6

---@type fltanim.buf_animator[]
local runners = vim.iter(fps):map(require('fltanim').new_buf_animator):totable()

---@type fltanim.animations[]
local animations = {
    'horizontal_indeterminate',
    'horizontal_bounce',
    'horizontal_fill',
}

local minwidth = 5
local buf = vim.api.nvim_create_buf(false, true)
---@type string[]
local text = {}
for i = 0, #animations - 1 do
    for j = 1, #fps do
        text[i * #fps + j] = ('%3d  %s'):format(fps[j], animations[i + 1])
    end
    minwidth = math.max(minwidth, 5 + width + #animations[i + 1])
end
vim.api.nvim_buf_set_lines(buf, 0, -1, true, text)

for i, anim in ipairs(animations) do
    for j, runner in ipairs(runners) do
        runner:set_animation(
            buf,
            (i - 1) * #runners + j,
            5,
            anim,
            { width = width, duration = duration }
        )
    end
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
local win2 = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    col = (vim.o.columns - minwidth) / 2,
    width = minwidth,
    row = (vim.o.lines - wh) / 2,
    height = wh,
    style = 'minimal',
    border = 'single',
    title = 'Horizontal animations',
})

vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win2),
    once = true,
    callback = function()
        timer:stop()
        timer:close()
        for _, runner in ipairs(runners) do
            runner:stop()
        end
    end,
})
