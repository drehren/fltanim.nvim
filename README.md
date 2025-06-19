# fltanim

An "animation" api/system for neovim.

It also comes with some default animations to be used.

## Requirements
- neovim >= 0.11.0

## Installation

Use your plugin manager to add this plugin to your installation.

## Usage

To add a nice animated icon to any buffer, you can simply do the following.

```lua
-- save this manager to keep the animations running
local buf_runner = require('fltanim').new_buf_animator(24)

-- ...

-- Insert a braille "spinner" animation in buffer 'buf', at line 'line', column 'col' (1-based, 0-based)
local buf_animation = buf_runner:set_animation(buf, line, col, 'braille_spinner')

-- Or a custom animation
local animation2 = buf_runner:set_animation(buf, line + 1, col, { 'o', 'O', 'o', 'O' }, { duration = 455 })
```

There is also the "runner", which will call whatever callback you provided, giving
the frame that should be shown.
```lua
local anim_id
local anim_frames = { 'o', 'O', 'o', 'O' }
-- or use one of the existing animations
-- local anim_frames = require('fltanim.symbols').horizontal_fill(6 --[[the cell width for this line]])
local runner = require('fltanim').new(24, function(items)
    for _, item in ipairs(items) do
        -- an items comes with the id given by create_animation, and
        -- the current frame string
        if item.id == anim_id then
            local new_frame = item.frame
            -- update 
        end
    end
end)

--- pass your "animation frames" and its duration
anim_id = runner:create_animation(anim_frames, 450)

vim.defer_fn(function()
    -- remove the animation after 5 seconds
    runner:animation_delete(anim_id)
end, 5000)
```

