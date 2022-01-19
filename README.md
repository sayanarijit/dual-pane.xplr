[![dual-pane82c66cadbbfcf1fe.gif](https://s10.gifyu.com/images/dual-pane82c66cadbbfcf1fe.gif)](https://gifyu.com/image/SSy11)

This plugin implements support for dual-pane navigation into xplr.

## Installation

### Install manually

- Add the following line in `~/.config/xplr/init.lua`

  ```lua
  local home = os.getenv("HOME")
  package.path = home
  .. "/.config/xplr/plugins/?/src/init.lua;"
  .. home
  .. "/.config/xplr/plugins/?.lua;"
  .. package.path
  ```

- Clone the plugin

  ```bash
  mkdir -p ~/.config/xplr/plugins

  git clone https://github.com/sayanarijit/dual-pane.xplr ~/.config/xplr/plugins/dual-pane
  ```

- Require the module in `~/.config/xplr/init.lua`

  ```lua
  require("dual-pane").setup()

  -- Or

  require("dual-pane").setup{
    active_pane_width = { Percentage = 70 },
    inactive_pane_width = { Percentage = 30 },
  }

  ```

## Usage

Press `ctrl-w` and then `h` or `left` to activate the left pane.

Press `ctrl-w` and then `l` or `right` to activate the right pane.

Press `ctrl-w` and then `1` to switch back to the default layout.

## Features

- Retains focus, sorters & filters.
- Shares selection.
