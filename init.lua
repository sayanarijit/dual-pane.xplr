---@diagnostic disable
local xplr = xplr
---@diagnostic enable

local pane = {
  LEFT = "left",
  RIGHT = "right",
}

local state = {
  active = nil,
  inactive = nil,
}

local inactive_pane_layout = {
  Dynamic = "custom.dual_pane.render_inactive_pane",
}

local function split_pane(left_pane_width, right_pane_width, left_pane, right_pane)
  local layout = {
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

  return xplr.util.layout_replace(xplr.config.layouts.builtin.default, "Table", layout)
end

local function offset(listing, height, focus)
  local h = height - 3
  local start = (focus - (focus % h))
  local result = {}
  for i = start + 1, start + h, 1 do
    table.insert(result, listing[i])
  end
  return result, start
end

local function activate_pane(pane_, app)
  local layout = pane_ .. "_pane_active"

  if state.active == nil then
    state.active = pane_
    state.inactive = app
    return {
      { SwitchLayoutCustom = layout },
    }
  elseif state.active ~= pane_ then
    local pwd = state.inactive.pwd
    local sorters = state.inactive.explorer_config.sorters
    local filters = state.inactive.explorer_config.filters
    local focus = (state.inactive.directory_buffer or {}).focus or 0

    state.inactive = app
    state.active = pane_

    local msgs = {
      "ClearNodeFilters",
      "ClearNodeSorters",
    }

    for _, v in ipairs(filters) do
      table.insert(msgs, { AddNodeFilter = { filter = v.filter, input = v.input } })
    end

    for _, v in ipairs(sorters) do
      table.insert(msgs, { AddNodeSorter = { sorter = v.sorter, reverse = v.reverse } })
    end

    table.insert(msgs, { ChangeDirectory = pwd })
    table.insert(msgs, { FocusByIndex = focus })
    table.insert(msgs, { SwitchLayoutCustom = layout })
    return msgs
  end
end

local function to_col_renderer_arg(node, index, focus, total, is_selected, ui, tree)
  node.index = index
  node.relative_index = math.abs(index - focus)
  node.is_before_focus = index < focus
  node.is_after_focus = index > focus
  node.tree = tree
  node.prefix = ui.prefix or ""
  node.suffix = ui.suffix or ""
  node.is_selected = is_selected
  node.is_focused = index == focus
  node.total = total
  node.style = ui.style
  node.meta = {}
  return node
end

local function render_inactive_pane(ctx)
  if state.inactive == nil then
    return { CustomParagraph = "" }
  end
  local nodes = (state.inactive.directory_buffer or {}).nodes or {}
  local total = #nodes
  local focus = (state.inactive.directory_buffer or {}).focus or 0

  local col_widths = xplr.config.general.table.col_widths
  local cols = xplr.config.general.table.row.cols

  local builtin = "builtin."
  local custom = "custom."

  local body = { {} }

  for hi, header in ipairs(xplr.config.general.table.header.cols) do
    body[1][hi] = header.format or ""
  end

  local is_selected = {}
  for _, v in ipairs(ctx.app.selection) do
    is_selected[v.absolute_path] = true
  end

  local visible, start = offset(nodes, ctx.layout_size.height, focus)
  for ni, node in ipairs(visible) do
    local index = start + ni - 1
    ni = ni + 1
    local tree = xplr.config.general.table.tree
    local t = tree[2].format or ""
    if index == 0 then
      t = tree[1].format or ""
    elseif index == total - 1 then
      t = tree[3].format or ""
    end

    local ui = xplr.config.general.default_ui
    if node.is_focused and node.is_selected then
      ui = xplr.config.general.focus_selection_ui
    elseif node.is_focused then
      ui = xplr.config.general.focus_ui
    elseif node.is_selected then
      ui = xplr.config.general.selection_ui
    end

    local arg = to_col_renderer_arg(
      node,
      index,
      focus,
      total,
      is_selected[node.absolute_path] or false,
      ui,
      t
    )
    body[ni] = {}
    for ci, col in ipairs(cols) do
      local render_name = col.format or ""
      if string.sub(render_name, 1, #builtin) == builtin then
        render_name = string.sub(render_name, #builtin + 1)
        body[ni][ci] = xplr.fn.builtin[render_name](arg)
      elseif string.sub(render_name, 1, #custom) == custom then
        render_name = string.sub(render_name, #custom + 1)
        body[ni][ci] = xplr.fn.custom[render_name](arg)
      else
        body[ni][ci] = "invalid renderer: " .. render_name
      end
    end
  end

  local dim = { add_modifiers = { "Dim" } }

  local title = " "
      .. xplr.util.shorten(state.inactive.pwd, { without_suffix_dots = true })
      .. " ("
      .. total
      .. ")"

  return {
    CustomTable = {
      ui = { title = { format = title, style = dim } },
      widths = col_widths,
      body = body,
    },
  }
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

  -- Also overwrite the default quit function

  xplr.config.modes.builtin.default.key_bindings.on_key.q = on_key.q

  xplr.config.layouts.custom.left_pane_active = split_pane(
    args.active_pane_width,
    args.inactive_pane_width,
    "Table",
    inactive_pane_layout
  )

  xplr.config.layouts.custom.right_pane_active = split_pane(
    args.inactive_pane_width,
    args.active_pane_width,
    inactive_pane_layout,
    "Table"
  )

  xplr.fn.custom.dual_pane = {}
  xplr.fn.custom.dual_pane.render_inactive_pane = render_inactive_pane

  xplr.fn.custom.dual_pane.activate_left_pane = function(ctx)
    return activate_pane(pane.LEFT, ctx)
  end

  xplr.fn.custom.dual_pane.activate_right_pane = function(ctx)
    return activate_pane(pane.RIGHT, ctx)
  end

  xplr.fn.custom.dual_pane.toggle_pane = function(ctx)
    if state.active == pane.RIGHT then
      return xplr.fn.custom.dual_pane.activate_left_pane(ctx)
    else
      return xplr.fn.custom.dual_pane.activate_right_pane(ctx)
    end
  end

  xplr.fn.custom.dual_pane.quit_active_pane = function(ctx)
    if state.active then
      local msgs = xplr.fn.custom.dual_pane.toggle_pane(ctx)
      table.insert(msgs, { SwitchLayoutBuiltin = "default" })
      state.active = nil
      return msgs
    else
      return {
        "Quit",
      }
    end
  end
end

return { setup = setup }
