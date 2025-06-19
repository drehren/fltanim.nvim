# fltanim

An "animation" api/system for neovim.

It also comes with some symbol animations.

## Requirements
- neovim >= 0.11.0

## Installation

Use your plugin manager to add this plugin to your installation. You
can also just download it to your runtimepath.

## Usage

To add a nice animated icon to any buffer, you can simply do the following.

```lua
-- save this manager to keep the animations running
local buf_runner = require('fltanim').create_buf_symbol_manager(24)

-- ...

-- Insert a braille "spinner" animation in buffer 'buf', at line 'line', column 'col' (1-based, 0-based)
local buf_animation = buf_runner:buf_insert_animated_symbol(buf, line, col, 'braille_spinner')

-- Or a custom animation
local animation2 = buf_runner:buf_insert_animated_symbol(buf, line + 1, col, { 'o', 'O', 'o', 'O' }, { duration = 455 })
```

There is also a manual mode, which allows control at frame level.
```lua
local anim_id
local anim_frames = { 'o', 'O', 'o', 'O' }
-- or use one of the existing animations
-- local anim_frames = require('fltanim.symbols').horizontal_fill(6 --[[the cell width for this line]])
local runner = require('fltanim').new(24, function(items)
    for _, item in ipairs(items) do
        if item.id == anim_id then
            local new_frame = anim_frames[anim_id]
            -- update whatever you will
        end
    end
end)

anim_id = runner:create_animation({ frames = #anim_frames, duration = 450 })

vim.defer_fn(function()
    -- remove the animation after 5 seconds
    runner:animation_delete(anim_id)
end, 5000)
```

The callback shown here will contain all items that should update its frame.
