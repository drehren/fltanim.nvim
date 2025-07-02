-- A barebones animation system for neovim

---@alias fltanim.animation integer

---@private
---@class fltanim.item
---@field animation fltanim.animations|string[]
---@field duration number
---@field frame_time number
---@field last_time number
---@field last_frame integer

---@class fltanim.item_frame
--- The id of the animation to update
---@field id fltanim.animation
--- The the frame to render
---@field frame string

---@alias fltanim.callable { __call: fun(tbl: any, updates: fltanim.item_frame[]) }

---@alias fltanim.callback fun(updates: fltanim.item_frame[])|fltanim.callable

---@class fltanim.runner
---@field private _fps integer
---@field package _timer uv.uv_timer_t
---@field package _items table<fltanim.animation, fltanim.item|false>
---@field package _on_frame fltanim.callback[]
---@field package _paused table<fltanim.animation, boolean>
---@field package _hr0 number
---@field package _removed integer
local R = {}
R.__index = R

---@class fltanim.animation_definition
--- Specifies the amount of frames for an animation
---@field frames integer
--- Specifies the animation duration in milliseconds
---@field duration number

local function gt0(value)
    return value > 0
end

--- Creates a new animation from a set of frames and duration and adds it to
--- the scheduler.
---
--- The scheduler is started if not running.
---@param animation fltanim.animations|string[] The animation frames
---@param duration number The animation duration in milliseconds
function R:create_animation(animation, duration)
    vim.validate('animation', animation, 'table')
    vim.validate('duration', duration, 'number')
    vim.validate('duration', duration, gt0, 'greater than zero')

    self._items[#self._items + 1] = {
        animation = animation,
        duration = duration,
        frame_time = duration / #animation,
        last_time = 0,
        last_frame = -1,
    }

    self:_activate()

    return #self._items
end

---@param on_frame fltanim.callback
function R:set_on_frame(on_frame)
    vim.validate('on_frame', on_frame, 'callable')
    self._on_frame = { on_frame }
end

---@param on_frame fltanim.callback
function R:push_on_frame(on_frame)
    vim.validate('on_frame', on_frame, 'callable')
    self._on_frame[#self._on_frame + 1] = on_frame
end

function R:pop_on_frame()
    self._on_frame[#self._on_frame] = nil
end

local hrtime = vim.uv.hrtime

---@private
function R:_activate()
    if #self._on_frame == 0 or #self._items == 0 or self._timer:is_active() then
        return
    end
    self._hr0 = hrtime()
    if self._timer:again() then
        return
    end
    local weakme = setmetatable({}, { __mode = 'v' })
    weakme.me = self
    local timer = self._timer
    self._timer:start(0, 1000 / self._fps, function()
        if not weakme.me then
            timer:stop()
            timer:close()
            return
        end
        local me = weakme.me
        local hr1 = hrtime()
        local delay = (hr1 - weakme.me._hr0) * 1e-6
        weakme.me._hr0 = hr1

        local updates = {}
        for id, a in pairs(me._items) do
            if a and not me._paused[id] then
                a.last_time = (a.last_time + delay) % a.duration
                local frame = math.floor(a.last_time / a.frame_time)
                if frame ~= a.last_frame then
                    a.last_frame = frame
                    if a.animation then
                        updates[#updates + 1] =
                            { id = id, frame = a.animation[frame + 1] }
                    else
                        updates[#updates + 1] = { id = id, frame = frame + 1 }
                    end
                end
            end
        end
        if #updates > 0 then
            for _, cb in ipairs(me._on_frame) do
                ---@diagnostic disable-next-line: param-type-mismatch
                local ok, err = pcall(cb, updates)
                if not ok then
                    vim.schedule(function()
                        vim.api.nvim_echo({ { err } }, true, { err = true })
                    end)
                end
            end
        elseif me._removed == #me._items then
            me._timer:stop()
        end
    end)
end

--- Deletes the specified animation.
---@param animation fltanim.animation Animation id.
function R:animation_delete(animation)
    vim.validate('animation', animation, 'number')
    if self._items[animation] then
        self._items[animation] = nil
        self._removed = self._removed + 1
    end
end

--- Stops the animation runner.
function R:stop()
    if self._timer:is_active() then
        self._timer:stop()
    end
end

--- Checks if the animation runner is running.
function R:is_running()
    return not not pcall(vim.uv.is_active, self._timer)
end

--- Restarts the animation runner.
function R:restart()
    if not self._timer:is_active() then
        self:_activate()
    end
end

--- Pauses the specified animation.
---@param animation fltanim.animation Animation id
function R:animation_pause(animation)
    if self._items[animation] then
        self._paused[animation] = true
    end
end

--- Unpauses the specified animation.
---
--- Starts the animation scheduler if it was stopped.
---@param animation fltanim.animation Animation id
function R:animation_unpause(animation)
    if self._items[animation] and self._paused[animation] then
        self._paused[animation] = false
        if not self._timer:is_active() then
            self:_activate()
        end
    end
end

--- Checks if the given animation is currently paused.
---@param animation fltanim.animation Animation id
---@return boolean is_paused
function R:animation_is_paused(animation)
    return not self:is_running() or self._paused[animation]
end

---@class fltanim.buf_animator_item
---@field buf integer
---@field em integer
---@field em_pos integer
---@field hl_group integer|string|(integer|string)[]

---@class fltanim.buf_animator
---@field private _runner fltanim.runner
---@field package _ns integer
---@field package _bufanim table<integer, fltanim.buf_animator_item>
---@operator call:fltanim.item_frame[]
local B = {}
B.__index = B

---@alias fltanim.set_animation.position 'inline'|'eol'|'eol_right_align'|'right_align'

--- Options when setting an animation in a buffer
---@class fltanim.buf_animator.set_animation_opts
---Width for animations that can use more than one cell of width
---@field width? integer
---Animation duration
---@field duration? number
---Highlight group(s) for animation, by name or id
---@field hl_group? string|integer|(string|integer)[]
---Defines where should the animation go in the line
---@field pos? fltanim.set_animation.position

--- Inserts an animation to a buffer, at the specified line and col.
---
--- The animation is handled with an extmark.
---@param buf integer Buffer id
---@param line integer 1-indexed line
---@param col integer|'$' 0-indexed column or '$' for last column
---@param animation fltanim.animations One of the available animations, @see fltanim.animations
---@param opts? fltanim.buf_animator.set_animation_opts Animation options
---@return integer animation The animation id
function B:set_animation(buf, line, col, animation, opts)
    vim.validate('buf', buf, vim.api.nvim_buf_is_valid, 'valid buffer')
    vim.validate('line', line, 'number')
    vim.validate('col', col, { 'number', 'string' })
    if type(col) == 'string' then
        if col ~= '$' then
            error(("'col': expected '$', got: '%s'"):format(col))
        end
        col = #vim.api.nvim_buf_get_lines(buf, line - 1, line, true)[1] - 1
    end

    opts = opts or {}
    vim.validate('opts.pos', opts.pos, 'string', true)

    local markid =
        vim.api.nvim_buf_set_extmark(buf, self._ns, line - 1, col - 1, {
            virt_text_pos = opts.pos or 'inline',
            invalidate = true,
            undo_restore = false,
            strict = false,
        })

    opts.pos = nil

    ---@cast opts fltanim.buf_animator.set_animation_mark_opts
    return self:set_animation_mark(buf, animation, self._ns, markid, opts)
end

---@class fltanim.buf_animator.set_animation_mark_opts : fltanim.buf_animator.set_animation_opts
---Defines the position of the animation frame in extmark's virtual text
---@field mark_pos? integer

--- Inserts an animation to a buffer, as the last virt_text chunk in the
--- specified existing extmark.
---@param buf integer Buffer id
---@param animation fltanim.animations The animation to add
---@param mark_ns integer The existing extmark namespace
---@param mark_id integer The existing extmark id
---@param opts? fltanim.buf_animator.set_animation_mark_opts Animation options
---@return fltanim.animation
function B:set_animation_mark(buf, animation, mark_ns, mark_id, opts)
    vim.validate('buf', buf, vim.api.nvim_buf_is_valid, 'valid buffer')
    vim.validate('mark_id', mark_id, 'number')
    vim.validate('mark_ns', mark_ns, 'number')
    vim.validate('opts', opts, 'table', true)

    opts = opts or {}

    local emd = vim.api.nvim_buf_get_extmark_by_id(
        buf,
        mark_ns,
        mark_id,
        { details = true }
    )
    assert(#emd > 0, 'extmark does not exist')
    emd[3].ns_id = nil

    if not opts.hl_group then
        -- Try find if the text has highlight
        local hl_items = vim.inspect_pos(buf, emd[1], emd[2])
        opts.hl_group = {}
        for _, item in ipairs(hl_items.extmarks) do
            opts.hl_group[#opts.hl_group + 1] = item.opts.hl_group
        end
        for _, item in ipairs(hl_items.semantic_tokens) do
            opts.hl_group[#opts.hl_group + 1] = item.opts.hl_group
        end
        for _, item in ipairs(hl_items.treesitter) do
            opts.hl_group[#opts.hl_group + 1] = item.hl_group
        end
        for _, item in ipairs(hl_items.syntax) do
            opts.hl_group[#opts.hl_group + 1] = item.hl_group
        end
    end

    local frames, duration =
        require('fltanim.animations')[animation](opts.width)

    ---@cast emd {[1]: integer, [2]: integer, [3]: vim.api.keyset.set_extmark}
    emd[3].id = mark_id

    if not emd[3].virt_text then
        emd[3].virt_text = { { frames[1], opts.hl_group } }
        emd[3].virt_text_pos = 'inline'
    else
        table.insert(
            emd[3].virt_text,
            opts.mark_pos or #emd[3].virt_text,
            { frames[1], opts.hl_group }
        )
    end

    local animid =
        self._runner:create_animation(frames, opts.duration or duration)

    vim.api.nvim_buf_set_extmark(buf, mark_ns, emd[1], emd[2], emd[3])
    self._bufanim[animid] = {
        buf = buf,
        em = mark_id,
        em_pos = #emd[3].virt_text,
        hl_group = opts.hl_group,
    }

    return animid
end

--- Pauses the specified animation.
---@param animation fltanim.animation Animation id
function B:animation_pause(animation)
    self._runner:animation_pause(animation)
end

--- Checks if the given animation is currently paused.
---@param animation fltanim.animation Animation id
---@return boolean is_paused
function B:animation_is_paused(animation)
    return self._runner:animation_is_paused(animation)
end

--- Unpauses the specified animation.
---
--- Starts the animation scheduler if it was stopped.
---@param animation fltanim.animation Animation id
function B:animation_unpause(animation)
    self._runner:animation_unpause(animation)
end

--- Deletes the specified animation.
---@param animation fltanim.animation Animation id.
function B:animation_delete(animation)
    if self._bufanim[animation] then
        self._runner:animation_delete(animation)
        local banim = self._bufanim[animation]
        self._bufanim[animation] = nil
        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(banim.buf) then
                return
            end
            vim.api.nvim_buf_del_extmark(banim.buf, self._ns, banim.em)
        end)
    end
end

--- Stops the animation runner.
function B:stop()
    self._runner:stop()
end

--- Restarts the animation runner.
function B:restart()
    self._runner:restart()
end

---@overload fun(self: fltanim.buf_animator, items: fltanim.item_frame[])
B.__call = vim.schedule_wrap(function(self, items)
    for _, item in ipairs(items) do
        local a = self._bufanim[item.id]
        if a then
            local e =
                vim.api.nvim_buf_get_extmark_by_id(a.buf, self._ns, a.em, {
                    details = true,
                })
            if #e > 0 and not e[3].invalid then
                e[3].virt_text[1][a.em_pos] = item.frame
                e[3].ns_id = nil
                ---@cast e {[1]: integer, [2]: integer, [3]: vim.api.keyset.set_extmark}
                e[3].id = a.em
                vim.api.nvim_buf_set_extmark(a.buf, self._ns, e[1], e[2], e[3])
            end
        end
    end
end)

local M = {}

--- Creates a new animation runner.
---@param fps integer Frames per second
---@param on_frame? fltanim.callback Callbacks when a frame should be drawn.
function M.new(fps, on_frame)
    vim.validate('fps', fps, 'number')
    vim.validate('on_frame', on_frame, 'callable', true)
    ---@type fltanim.runner
    local runner = {
        _fps = fps,
        _timer = assert(vim.uv.new_timer()),
        _on_frame = { on_frame },
        _items = {},
        _paused = {},
        _hr0 = 0,
        _removed = 0,
        _ns = vim.api.nvim_create_namespace(''),
    }
    return setmetatable(runner, R)
end

--- Creates a buffer symbol animator manager
---@param fps integer Animation frames per second
---@return fltanim.buf_animator
function M.new_buf_animator(fps)
    local manager = {
        _ns = vim.api.nvim_create_namespace(''),
        _bufanim = {},
    }
    manager._runner = M.new(fps, setmetatable(manager, B))
    return manager
end

return M
