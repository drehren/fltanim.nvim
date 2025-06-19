local indet_line = {}
local bounce = {}
local fill_line = {}

local function validate_width(value)
    return value > 1
end

local M
---@enum (key) fltanim.animations
M = {
    ---Creates the frames for a spinner based on braille dots
    ---@return table frames, number duration
    dot_spinner = function()
        return { '⠷', '⠯', '⠟', '⠻', '⠽', '⠾' }, 600
    end,

    ---Creates the frames for a spinner based on circle with cuadrant symbols
    ---@return table frames, number duration
    clock_spinner = function()
        return { '◷', '◶', '◵', '◴' }, 800
    end,

    ---Creates the frames for a spinner based on box drawing edges
    ---@return table frames, number duration
    box_edge_spinner = function()
        return { '└', '├', '┌', '┬', '┐', '┤', '┘', '┴' }, 1000
    end,

    ---Creates the frames for a spinner based on box quadrants
    ---@return table frames, number duration
    box_1q_spinner = function()
        return { '▘', '▝', '▗', '▖' }, 600
    end,

    ---Creates the frames for a spinner based on box quadrants
    ---@return table frames, number duration
    box_2q_spinner = function()
        return { '▀', '▚', '▐', '▞', '▄', '▚', '▌', '▞' }, 1200
    end,

    ---Creates the frames for a spinner based on box quadrants
    ---@return table frames, number duration
    box_3q_spinner = function()
        return { '▜', '▟', '▙', '▛' }, 800
    end,

    ---Creates the frames for a filling block using box quadrants
    ---@return table frames, number duration
    box_fill = function()
        return { '▘', '▀', '▜', '█' }, 800
    end,

    ---Creates the frames for a filling vertical bar
    ---@return table frames, number duration
    vbar_fill = function()
        return { '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█' }, 2000
    end,

    ---Creates the frames to animate an indeterminate horizontal line
    ---@param width integer The width in cell units of the line
    ---@return table frames, number duration
    horizontal_indeterminate = function(width)
        vim.validate('width', width, 'number')
        vim.validate('width', width, validate_width, 'greater or equal to 2')
        width = math.floor(width)

        if indet_line[width] then
            return vim.deepcopy(indet_line[width]), 1000 * math.log(width, 6)
        end
        local frames = {}
        local amount = width / 6
        local part = ('█'):rep(math.floor(amount))
        frames[1] = ('█%s'):format(part)
        frames[2] = ('▐%s▌'):format(part)

        local blockstep = 1 / #frames
        local extrasteps = vim.iter(frames)
            :map(function(v)
                return vim.fn.strwidth(v) - 1
            end)
            :fold(0, function(a, b)
                return a + b
            end)

        local steps = math.ceil(width * #frames) - extrasteps
        local symbols = {}
        for i = 0, steps - 1 do
            local a = math.floor(i * blockstep)
            local b = (i % #frames) + 1
            local c = width - a - vim.fn.strwidth(frames[b])
            symbols[#symbols + 1] = ('%s%s%s'):format(
                (' '):rep(a),
                frames[b],
                (' '):rep(c)
            )
        end
        indet_line[width] = symbols
        return vim.deepcopy(symbols), 1000 * math.log(width, 6)
    end,

    ---Creates the frames for a "bouncing" block in an horizontal line
    ---@param width integer The width of the line in cells
    ---@return table frames, number duration
    horizontal_bounce = function(width)
        vim.validate('width', width, 'number')
        vim.validate('width', width, validate_width, 'greater or equal to 2')
        width = math.floor(width)

        if bounce[width] then
            return vim.deepcopy(bounce[width]), 1000 * math.log(width, 6)
        end
        local symbols = M.horizontal_indeterminate(width)
        for i = #symbols - 1, 2, -1 do
            symbols[#symbols + 1] = symbols[i]
        end
        bounce[width] = symbols
        return vim.deepcopy(symbols), 1000 * math.log(width, 6)
    end,

    ---Creates the frames for a filling horizontal line
    ---@param width integer The width of the line in cells
    ---@return table frames, number duration
    horizontal_fill = function(width)
        vim.validate('width', width, 'number')
        vim.validate('width', width, validate_width, 'greater or equal to 2')
        width = math.floor(width)

        if fill_line[width] then
            return vim.deepcopy(fill_line[width]), 1000 * math.log(width, 6)
        end
        local symbols = {}
        local frames = { '▎', '▌', '▊', '█' }
        local steps = width * #frames
        for i = 0, steps - 1 do
            local a = math.floor(i / #frames)
            local b = i % #frames + 1
            local c = width - a - vim.fn.strwidth(frames[b])
            symbols[#symbols + 1] = ('%s%s%s'):format(
                frames[#frames]:rep(a),
                frames[b],
                (' '):rep(c)
            )
        end
        fill_line[width] = symbols
        return vim.deepcopy(symbols), 1000 * math.log(width, 6)
    end,
}

setmetatable(M, {
    __index = function(t, k)
        if type(k) == 'table' then
            return function()
                return k, 166 * #k
            end
        end
        if not rawget(t, k) then
            error(("symbol '%s' does not exist"):format(k), 2)
        end
        return t[k]
    end,
})

return M
