---@diagnostic disable
local xplr = xplr
---@diagnostic enable

local pane = {
  LEFT = 1,
  RIGHT = 2,
}

local dual_pane = nil

local inactive_pane_layout = {
  CustomContent = {
    title = nil,
    body = {
      DynamicList = { render = "custom.dual_pane.render_inactive_pane" },
    },
  },
}

local function deepcopy(obj)
  if type(obj) ~= "table" then
    return obj
  end
  local res = {}
  for k, v in pairs(obj) do
    res[deepcopy(k)] = deepcopy(v)
  end
  return res
end

local function split_pane(
  layout,
  left_pane_width,
  right_pane_width,
  left_pane,
  right_pane
)
  if layout == "Table" then
    return {
      Horizontal = {
        config = {
          constraints = {
            left_pane_width,
            right_pane_width,
          },
        },
        splits = {
          left_pane,
          right_pane,
        },
      },
    }
  elseif layout.Horizontal or layout.Vertical then
    local res = deepcopy(layout)
    for _, v in pairs(res) do
      for i, l in ipairs(v.splits) do
        v.splits[i] = split_pane(
          l,
          left_pane_width,
          right_pane_width,
          left_pane,
          right_pane
        )
      end
    end
    return res
  else
    return layout
  end
end

local function activate_pane(pane_, layout, ctx)
  if dual_pane == nil then
    dual_pane = {
      active = pane_,
      inactive = {
        directory_buffer = ctx.directory_buffer,
        explorer_config = ctx.explorer_config,
      },
    }
    return { { SwitchLayoutCustom = layout } }
  end

  if dual_pane.active ~= pane_ then
    local pwd = dual_pane.inactive.directory_buffer.parent
    local focus = dual_pane.inactive.directory_buffer.focus
    local sorters = dual_pane.inactive.explorer_config.sorters
    local filters = dual_pane.inactive.explorer_config.filters

    dual_pane.inactive.directory_buffer = deepcopy(ctx.directory_buffer)
    dual_pane.inactive.explorer_config = deepcopy(ctx.explorer_config)
    dual_pane.active = pane_

    local msgs = {
      "ClearNodeFilters",
      "ClearNodeSorters",
    }

    for _, v in ipairs(filters) do
      table.insert(
        msgs,
        { AddNodeFilter = { filter = v.filter, input = v.input } }
      )
    end

    for _, v in ipairs(sorters) do
      table.insert(
        msgs,
        { AddNodeSorter = { sorter = v.sorter, reverse = v.reverse } }
      )
    end

    table.insert(msgs, { ChangeDirectory = pwd })
    table.insert(msgs, { FocusByIndex = focus })
    table.insert(msgs, { SwitchLayoutCustom = layout })

    return msgs
  end
end

local function setup(args)
  args = args or {}
  args.active_pane_width = args.active_pane_width or { Percentage = 70 }
  args.inactive_pane_width = args.inactive_pane_width or { Percentage = 30 }

  local on_key = xplr.config.modes.builtin.switch_layout.key_bindings.on_key

  on_key.h = {
    help = "left pane",
    messages = {
      "PopMode",
      { CallLuaSilently = "custom.dual_pane.activate_left_pane" },
    },
  }

  on_key.l = {
    help = "right pane",
    messages = {
      "PopMode",
      { CallLuaSilently = "custom.dual_pane.activate_right_pane" },
    },
  }

  on_key.w = {
    help = "toggle pane",
    messages = {
      "PopMode",
      { CallLuaSilently = "custom.dual_pane.toggle_pane" },
    },
  }

  on_key.q = {
    help = "quit pane",
    messages = {
      "PopMode",
      { CallLuaSilently = "custom.dual_pane.quit_active_pane" },
    },
  }

  on_key["ctrl-h"] = on_key.h
  on_key["ctrl-l"] = on_key.l
  on_key["ctrl-w"] = on_key.w
  on_key["ctrl-q"] = on_key.q

  on_key.left = on_key.h
  on_key["ctrl-left"] = on_key.left

  on_key.right = on_key.l
  on_key["ctrl-right"] = on_key.right

  local default_layout = xplr.config.layouts.builtin.default
  xplr.config.layouts.custom.left_pane_active = split_pane(
    default_layout,
    args.active_pane_width,
    args.inactive_pane_width,
    "Table",
    inactive_pane_layout
  )

  xplr.config.layouts.custom.right_pane_active = split_pane(
    default_layout,
    args.inactive_pane_width,
    args.active_pane_width,
    inactive_pane_layout,
    "Table"
  )

  xplr.fn.custom.dual_pane = {}
  xplr.fn.custom.dual_pane.render_inactive_pane = function(ctx)
    local tree = xplr.config.general.table.tree
    if dual_pane == nil or dual_pane.inactive.directory_buffer == nil then
      return {}
    else
      local buf = dual_pane.inactive.directory_buffer
      local res = {
        buf.parent .. " (" .. buf.total .. ")",
      }

      local h = ctx.layout_size.height - 3
      local start = (buf.focus - (buf.focus % h))
      for i = start + 1, start + h, 1 do
        if i > buf.total then
          break
        end
        local node = dual_pane.inactive.directory_buffer.nodes[i]
        local path = node.relative_path
        if i == buf.total then
          path = tree[3].format .. " " .. path
        elseif i == 1 then
          path = tree[1].format .. " " .. path
        else
          path = tree[2].format .. " " .. path
        end

        if node.is_dir then
          path = path .. "/"
        end

        table.insert(res, path)
      end
      return res
    end
  end

  xplr.fn.custom.dual_pane.activate_left_pane = function(ctx)
    return activate_pane(pane.LEFT, "left_pane_active", ctx)
  end

  xplr.fn.custom.dual_pane.activate_right_pane = function(ctx)
    return activate_pane(pane.RIGHT, "right_pane_active", ctx)
  end

  xplr.fn.custom.dual_pane.toggle_pane = function(ctx)
    if dual_pane and dual_pane.active == pane.RIGHT then
      return xplr.fn.custom.dual_pane.activate_left_pane(ctx)
    else
      return xplr.fn.custom.dual_pane.activate_right_pane(ctx)
    end
  end

  xplr.fn.custom.dual_pane.quit_active_pane = function(ctx)
    if dual_pane then
      local msgs = xplr.fn.custom.dual_pane.toggle_pane(ctx)
      table.insert(msgs, { SwitchLayoutBuiltin = "default" })
      dual_pane = nil
      return msgs
    else
      return {
        { SwitchModeBuiltin = "quit" },
      }
    end
  end
end

return { setup = setup }
