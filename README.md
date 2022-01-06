[![dual-pane.gif](https://s10.gifyu.com/images/dual-pane.gif)](https://gifyu.com/image/SSyuk)

This plugin implements support for dual-pane navigation into xplr.

## Installation

### Install manually

- Add the following line in `~/.config/xplr/init.lua`

  ```lua
  package.path = os.getenv("HOME") .. '/.config/xplr/plugins/?/src/init.lua'
  ```

- Clone the plugin

  ```bash
  mkdir -p ~/.config/xplr/plugins

  git clone https://github.com/me/dual-pane.xplr ~/.config/xplr/plugins/dual-pane
  ```

- Require the module in `~/.config/xplr/init.lua`

  ```lua
  require("dual-pane").setup()

  -- Or

  require("dual-pane").setup{
    active_pane_width = { Percentage = 70 }
    inactive_pane_width = { Percentage = 30 }
  }

  ```

## Usage

Press `ctrl-w` and then `h` or `left` to activate the left pane.
Press `ctrl-w` and then `l` or `right` to activate the right pane.
Press `ctrl-w` and then `0` to switch back to the default pane.

## Features

- Retains focus and selection.
- Retains sorters & filters.
