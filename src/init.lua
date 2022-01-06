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
        directory_buffer = deepcopy(ctx.directory_buffer),
        explorer_config = deepcopy(ctx.explorer_config),
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

local function setup()
  local on_key = xplr.config.modes.builtin.switch_layout.key_bindings.on_key

  on_key.h = {
    help = "left pane",
    messages = {
      { CallLuaSilently = "custom.dual_pane.activate_left_pane" },
      "PopMode",
    },
  }

  on_key.l = {
    help = "right pane",
    messages = {
      { CallLuaSilently = "custom.dual_pane.activate_right_pane" },
      "PopMode",
    },
  }

  on_key.left = on_key.h
  on_key.right = on_key.l

  local default_layout = xplr.config.layouts.builtin.default
  xplr.config.layouts.custom.left_pane_active = split_pane(
    default_layout,
    { Percentage = 70 },
    { Percentage = 30 },
    "Table",
    inactive_pane_layout
  )

  xplr.config.layouts.custom.right_pane_active = split_pane(
    default_layout,
    { Percentage = 30 },
    { Percentage = 70 },
    inactive_pane_layout,
    "Table"
  )

  xplr.fn.custom.dual_pane = {}
  xplr.fn.custom.dual_pane.render_inactive_pane = function(_)
    if dual_pane == nil or dual_pane.inactive.directory_buffer == nil then
      return {}
    else
      local buf = dual_pane.inactive.directory_buffer
      local res = {
        buf.parent .. " (" .. buf.total .. ")",
        " ",
      }
      for _, node in ipairs(dual_pane.inactive.directory_buffer.nodes) do
        table.insert(res, node.relative_path)
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
end

return { setup = setup }
