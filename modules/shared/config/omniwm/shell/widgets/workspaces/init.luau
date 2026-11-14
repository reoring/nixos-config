-- Custom workspace grid: 15 workspaces as a 5x3 grid of small squares.
--   row 1: q w e r t  (1-5)
--   row 2: a s d f g  (6-10)
--   row 3: z x c v b  (11-15)
-- Filled square = current workspace, outline = everything else.
-- Overrides the default style's "workspaces" widget (top-level widgets win).

spanIslands = true

local COLUMNS = 5
local ROWS = 3
local GAP = 2

local function cellSize(bar: Bar): number
    local height = (bar.style and bar.style.height) or 32
    return math.max(4, math.floor((height - 4 - GAP * (ROWS - 1)) / ROWS))
end

local function cell(workspace: BarWorkspace?, size: number)
    if workspace == nil then
        return ui.box{ w = size, h = size }
    end
    local props = {
        w = size, h = size, radius = 1.5,
        border = workspace.focused and "accent" or "secondaryForeground/0.7",
        borderWidth = 1,
        fill = if workspace.focused then "accent" else nil,
        hover = "accent/0.5",
        help = workspace.name,
        target = "workspace " .. workspace.id,
        drop = true,
        animate = 0.12,
    }
    if not workspace.focused then
        props.onClick = "switch-workspace " .. workspace.id
    end
    return ui.box(props)
end

function render(ctx: Context)
    local bar = ctx.data.bar
    local list = {}
    for _, workspace in ipairs(bar.workspaces) do
        if bar.island == "all" or workspace.focused == (bar.island == "active") then
            list[#list + 1] = workspace
        end
    end
    local size = cellSize(bar)
    local grid = { gap = GAP, pad = 2 }
    for r = 0, ROWS - 1 do
        local row = { gap = GAP }
        for c = 1, COLUMNS do
            row[#row + 1] = cell(list[r * COLUMNS + c], size)
        end
        grid[#grid + 1] = ui.row(row)
    end
    return ui.column(grid)
end
