-- Base OS: monitor drawing + touch buttons
-- Every write is padded to a fixed width, so the screen never needs clearing between frames (no flicker).

local ui = {}
ui.__index = ui

function ui.new(mon)
    local self = setmetatable({ mon = mon, buttons = {} }, ui)
    self:resize()
    return self
end

function ui:resize()
    self.w, self.h = self.mon.getSize()
end

function ui:clear()
    self.mon.setBackgroundColor(colors.black)
    self.mon.clear()
    self.buttons = {}
end

--------------------------------------------------
-- TEXT
--------------------------------------------------

-- Write text at x,y. With a width, the text is padded/truncated to exactly that many cells.
function ui:text(x, y, text, fg, bg, width)
    if y < 1 or y > self.h or x > self.w then
        return
    end

    text = tostring(text)
    width = math.min(width or #text, self.w - x + 1)

    if width < 1 then
        return
    end

    if #text > width then
        text = width > 2 and text:sub(1, width - 2) .. ".." or text:sub(1, width)
    else
        text = text .. string.rep(" ", width - #text)
    end

    self.mon.setCursorPos(x, y)
    self.mon.setTextColor(fg or colors.white)
    self.mon.setBackgroundColor(bg or colors.black)
    self.mon.write(text)
end

-- Write text from x (default 1) to the right edge, overwriting whatever was there.
function ui:row(y, text, fg, bg, x)
    x = x or 1
    self:text(x, y, text, fg, bg, self.w - x + 1)
end

-- Blank every row from y1 to y2.
function ui:blank(y1, y2)
    for y = y1, y2 do
        self:row(y, "")
    end
end

function ui:center(y, text, fg, bg)
    local x = math.max(1, math.floor((self.w - #text) / 2) + 1)
    self:text(x, y, text, fg, bg)
end

-- Full-width bar across row 1, with optional text on the right (e.g. a clock).
function ui:titleBar(title, right)
    self:row(1, " " .. title, colors.white, colors.blue)

    if right then
        self:text(self.w - #right, 1, right, colors.lightGray, colors.blue)
    end
end

function ui:bar(x, y, width, pct, color)
    width = math.min(width, self.w - x + 1)

    if y < 1 or y > self.h or width < 1 then
        return
    end

    pct = math.max(0, math.min(1, tonumber(pct) or 0))

    local filled = math.floor(width * pct)

    self.mon.setCursorPos(x, y)
    self.mon.setBackgroundColor(color or colors.lime)
    self.mon.write(string.rep(" ", filled))
    self.mon.setBackgroundColor(colors.gray)
    self.mon.write(string.rep(" ", width - filled))
    self.mon.setBackgroundColor(colors.black)
end

--------------------------------------------------
-- BUTTONS
--------------------------------------------------

-- Draw a button and register it for touch. ui:hit(x, y) returns its id.
function ui:button(id, x, y, width, height, label, fg, bg)
    for row = y, y + height - 1 do
        self:text(x, row, "", fg, bg, width)
    end

    local labelX = x + math.max(0, math.floor((width - #label) / 2))
    local labelY = y + math.floor((height - 1) / 2)

    self:text(labelX, labelY, label, fg, bg, math.min(#label, width))

    table.insert(self.buttons, {
        id = id,
        x1 = x,
        y1 = y,
        x2 = x + width - 1,
        y2 = y + height - 1
    })
end

function ui:clearButtons()
    self.buttons = {}
end

function ui:hit(x, y)
    for _, b in ipairs(self.buttons) do
        if x >= b.x1 and x <= b.x2 and y >= b.y1 and y <= b.y2 then
            return b.id
        end
    end
end

--------------------------------------------------
-- FORMATTING
--------------------------------------------------

function ui.fmt(n)
    n = tonumber(n) or 0

    if n >= 1000000000000 then
        return string.format("%.2fT", n / 1000000000000)
    elseif n >= 1000000000 then
        return string.format("%.2fB", n / 1000000000)
    elseif n >= 1000000 then
        return string.format("%.2fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
    else
        return tostring(math.floor(n))
    end
end

function ui.pct(used, total)
    used = tonumber(used) or 0
    total = tonumber(total) or 0

    if total <= 0 then
        return 0
    end

    return used / total
end

function ui.clock()
    return textutils.formatTime(os.time(), false)
end

return ui
