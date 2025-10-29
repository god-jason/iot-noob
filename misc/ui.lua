local ui = {}

-- 样式
local parts = {
    OBJ_PART_MAIN = lvgl.OBJ_PART_MAIN,
    OBJ_PART_ALL = lvgl.OBJ_PART_ALL,
    ARC_PART_BG = lvgl.ARC_PART_BG,
    ARC_PART_INDIC = lvgl.ARC_PART_INDIC,
    ARC_PART_KNOB = lvgl.ARC_PART_KNOB,
    CONT_PART_MAIN = lvgl.CONT_PART_MAIN,
    BTN_PART_MAIN = lvgl.BTN_PART_MAIN,
    LABEL_PART_MAIN = lvgl.LABEL_PART_MAIN,
    BAR_PART_BG = lvgl.BAR_PART_BG,
    BAR_PART_INDIC = lvgl.BAR_PART_INDIC,
    BTNMATRIX_PART_BG = lvgl.BTNMATRIX_PART_BG,
    BTNMATRIX_PART_BTN = lvgl.BTNMATRIX_PART_BTN,
    CALENDAR_PART_BG = lvgl.CALENDAR_PART_BG,
    CALENDAR_PART_HEADER = lvgl.CALENDAR_PART_HEADER,
    CALENDAR_PART_DAY_NAMES = lvgl.CALENDAR_PART_DAY_NAMES,
    CALENDAR_PART_DATE = lvgl.CALENDAR_PART_DATE,
    IMG_PART_MAIN = lvgl.IMG_PART_MAIN,
    CANVAS_PART_MAIN = lvgl.CANVAS_PART_MAIN,
    LINE_PART_MAIN = lvgl.LINE_PART_MAIN,
    CHART_PART_BG = lvgl.CHART_PART_BG,
    CHART_PART_SERIES_BG = lvgl.CHART_PART_SERIES_BG,
    CHART_PART_SERIES = lvgl.CHART_PART_SERIES,
    CHART_PART_CURSOR = lvgl.CHART_PART_CURSOR,
    CHECKBOX_PART_BG = lvgl.CHECKBOX_PART_BG,
    CHECKBOX_PART_BULLET = lvgl.CHECKBOX_PART_BULLET,
    CPICKER_PART_MAIN = lvgl.CPICKER_PART_MAIN,
    CPICKER_PART_KNOB = lvgl.CPICKER_PART_KNOB,
    PAGE_PART_BG = lvgl.PAGE_PART_BG,
    PAGE_PART_SCROLLBAR = lvgl.PAGE_PART_SCROLLBAR,
    PAGE_PART_EDGE_FLASH = lvgl.PAGE_PART_EDGE_FLASH,
    PAGE_PART_SCROLLABLE = lvgl.PAGE_PART_SCROLLABLE,
    DROPDOWN_PART_MAIN = lvgl.DROPDOWN_PART_MAIN,
    DROPDOWN_PART_LIST = lvgl.DROPDOWN_PART_LIST,
    DROPDOWN_PART_SCROLLBAR = lvgl.DROPDOWN_PART_SCROLLBAR,
    DROPDOWN_PART_SELECTED = lvgl.DROPDOWN_PART_SELECTED,
    LINEMETER_PART_MAIN = lvgl.LINEMETER_PART_MAIN,
    GAUGE_PART_MAIN = lvgl.GAUGE_PART_MAIN,
    GAUGE_PART_MAJOR = lvgl.GAUGE_PART_MAJOR,
    GAUGE_PART_NEEDLE = lvgl.GAUGE_PART_NEEDLE,
    IMGBTN_PART_MAIN = lvgl.IMGBTN_PART_MAIN,
    KEYBOARD_PART_BG = lvgl.KEYBOARD_PART_BG,
    KEYBOARD_PART_BTN = lvgl.KEYBOARD_PART_BTN,
    LED_PART_MAIN = lvgl.LED_PART_MAIN,
    LIST_PART_BG = lvgl.LIST_PART_BG,
    LIST_PART_SCROLLBAR = lvgl.LIST_PART_SCROLLBAR,
    LIST_PART_EDGE_FLASH = lvgl.LIST_PART_EDGE_FLASH,
    LIST_PART_SCROLLABLE = lvgl.LIST_PART_SCROLLABLE,
    MSGBOX_PART_BG = lvgl.MSGBOX_PART_BG,
    MSGBOX_PART_BTN_BG = lvgl.MSGBOX_PART_BTN_BG,
    MSGBOX_PART_BTN = lvgl.MSGBOX_PART_BTN,
    OBJMASK_PART_MAIN = lvgl.OBJMASK_PART_MAIN,
    ROLLER_PART_BG = lvgl.ROLLER_PART_BG,
    ROLLER_PART_SELECTED = lvgl.ROLLER_PART_SELECTED,
    SLIDER_PART_BG = lvgl.SLIDER_PART_BG,
    SLIDER_PART_INDIC = lvgl.SLIDER_PART_INDIC,
    SLIDER_PART_KNOB = lvgl.SLIDER_PART_KNOB,
    TEXTAREA_PART_BG = lvgl.TEXTAREA_PART_BG,
    TEXTAREA_PART_SCROLLBAR = lvgl.TEXTAREA_PART_SCROLLBAR,
    TEXTAREA_PART_EDGE_FLASH = lvgl.TEXTAREA_PART_EDGE_FLASH,
    TEXTAREA_PART_CURSOR = lvgl.TEXTAREA_PART_CURSOR,
    TEXTAREA_PART_PLACEHOLDER = lvgl.TEXTAREA_PART_PLACEHOLDER,
    SPINBOX_PART_BG = lvgl.SPINBOX_PART_BG,
    SPINBOX_PART_CURSOR = lvgl.SPINBOX_PART_CURSOR,
    SPINNER_PART_BG = lvgl.SPINNER_PART_BG,
    SPINNER_PART_INDIC = lvgl.SPINNER_PART_INDIC,
    SWITCH_PART_BG = lvgl.SWITCH_PART_BG,
    SWITCH_PART_INDIC = lvgl.SWITCH_PART_INDIC,
    SWITCH_PART_KNOB = lvgl.SWITCH_PART_KNOB,
    TABLE_PART_BG = lvgl.TABLE_PART_BG,
    TABLE_PART_CELL1 = lvgl.TABLE_PART_CELL1,
    TABLE_PART_CELL2 = lvgl.TABLE_PART_CELL2,
    TABLE_PART_CELL3 = lvgl.TABLE_PART_CELL3,
    TABLE_PART_CELL4 = lvgl.TABLE_PART_CELL4,
    WIN_PART_BG = lvgl.WIN_PART_BG,
    WIN_PART_HEADER = lvgl.WIN_PART_HEADER,
    WIN_PART_CONTENT_SCROLLABLE = lvgl.WIN_PART_CONTENT_SCROLLABLE,
    WIN_PART_SCROLLBAR = lvgl.WIN_PART_SCROLLBAR,
    TABVIEW_PART_BG = lvgl.TABVIEW_PART_BG,
    TABVIEW_PART_BG_SCROLLABLE = lvgl.TABVIEW_PART_BG_SCROLLABLE,
    TABVIEW_PART_TAB_BG = lvgl.TABVIEW_PART_TAB_BG,
    TABVIEW_PART_TAB_BTN = lvgl.TABVIEW_PART_TAB_BTN,
    TABVIEW_PART_INDIC = lvgl.TABVIEW_PART_INDIC,
    TILEVIEW_PART_BG = lvgl.TILEVIEW_PART_BG,
    TILEVIEW_PART_SCROLLBAR = lvgl.TILEVIEW_PART_SCROLLBAR,
    TILEVIEW_PART_EDGE_FLASH = lvgl.TILEVIEW_PART_EDGE_FLASH
}

-- 透明度
local opacties = {
    OPA_TRANSP = lvgl.OPA_TRANSP,
    OPA_0 = lvgl.OPA_0,
    OPA_10 = lvgl.OPA_10,
    OPA_20 = lvgl.OPA_20,
    OPA_30 = lvgl.OPA_30,
    OPA_40 = lvgl.OPA_40,
    OPA_50 = lvgl.OPA_50,
    OPA_60 = lvgl.OPA_60,
    OPA_70 = lvgl.OPA_70,
    OPA_80 = lvgl.OPA_80,
    OPA_90 = lvgl.OPA_90,
    OPA_100 = lvgl.OPA_100,
    OPA_COVER = lvgl.OPA_COVER
}

-- 对齐
local aligns = {
    CENTER = lvgl.ALIGN_CENTER,
    IN_TOP_LEFT = lvgl.ALIGN_IN_TOP_LEFT,
    IN_TOP_MID = lvgl.ALIGN_IN_TOP_MID,
    IN_TOP_RIGHT = lvgl.ALIGN_IN_TOP_RIGHT,
    IN_BOTTOM_LEFT = lvgl.ALIGN_IN_BOTTOM_LEFT,
    IN_BOTTOM_MID = lvgl.ALIGN_IN_BOTTOM_MID,
    IN_BOTTOM_RIGHT = lvgl.ALIGN_IN_BOTTOM_RIGHT,
    IN_LEFT_MID = lvgl.ALIGN_IN_LEFT_MID,
    IN_RIGHT_MID = lvgl.ALIGN_IN_RIGHT_MID,
    OUT_TOP_LEFT = lvgl.ALIGN_OUT_TOP_LEFT,
    OUT_TOP_MID = lvgl.ALIGN_OUT_TOP_MID,
    OUT_TOP_RIGHT = lvgl.ALIGN_OUT_TOP_RIGHT,
    OUT_BOTTOM_LEFT = lvgl.ALIGN_OUT_BOTTOM_LEFT,
    OUT_BOTTOM_MID = lvgl.ALIGN_OUT_BOTTOM_MID,
    OUT_BOTTOM_RIGHT = lvgl.ALIGN_OUT_BOTTOM_RIGHT,
    OUT_LEFT_TOP = lvgl.ALIGN_OUT_LEFT_TOP,
    OUT_LEFT_MID = lvgl.ALIGN_OUT_LEFT_MID,
    OUT_LEFT_BOTTOM = lvgl.ALIGN_OUT_LEFT_BOTTOM,
    OUT_RIGHT_TOP = lvgl.ALIGN_OUT_RIGHT_TOP,
    OUT_RIGHT_MID = lvgl.ALIGN_OUT_RIGHT_MID,
    OUT_RIGHT_BOTTOM = lvgl.ALIGN_OUT_RIGHT_BOTTOM
}

local label_aligns = {
    LEFT = lvgl.LABEL_ALIGN_LEFT,
    CENTER = lvgl.LABEL_ALIGN_CENTER,
    RIGHT = lvgl.LABEL_ALIGN_RIGHT,
    AUTO = lvgl.LABEL_ALIGN_AUTO
}

local fits = {
    NONE = lvgl.FIT_NONE,
    TIGHT = lvgl.FIT_TIGHT,
    PARENT = lvgl.FIT_PARENT,
    MAX = lvgl.FIT_MAX
}

local Widget = {}
Widget.__index = Widget

local Image = {}
setmetatable(Image, Widget)

local Line = {}
setmetatable(Line, Widget)

local Label = {}
setmetatable(Label, Widget)

local Led = {}
setmetatable(Led, Widget)

local Spinner = {}
setmetatable(Spinner, Widget)

local Arc = {}
setmetatable(Arc, Widget)

local Bar = {}
setmetatable(Bar, Widget)

local Button = {}
setmetatable(Button, Widget)

local ImageButton = {}
setmetatable(ImageButton, Widget)

local TextArea = {}
setmetatable(TextArea, Widget)

local Switch = {}
setmetatable(Switch, Widget)

local Checkbox = {}
setmetatable(Checkbox, Widget)

local Dropdown = {}
setmetatable(Dropdown, Widget)

local Slider = {}
setmetatable(Slider, Widget)

local SpinBox = {}
setmetatable(SpinBox, Widget)

local ColorPicker = {}
setmetatable(ColorPicker, Widget)

local Table = {}
setmetatable(Table, Widget)

local Chart = {}
setmetatable(Chart, Widget)

local Gauge = {}
setmetatable(Gauge, Widget)

local LineMeter = {}
setmetatable(LineMeter, Widget)

local Container = {}
setmetatable(Container, Widget)

local List = {}
setmetatable(List, Widget)

local Roller = {}
setmetatable(Roller, Widget)

local MsgBox = {}
setmetatable(MsgBox, Widget)

local TileView = {}
setmetatable(TileView, Widget)

local TabView = {}
setmetatable(TabView, Widget)

local Window = {}
setmetatable(Window, Widget)

local ObjectMask = {}
setmetatable(ObjectMask, Widget)

local Page = {}
setmetatable(Page, Widget)

function Widget:new(obj)
    return setmetatable({
        obj = obj
    }, self)
end

function Widget:setPosition(x, y)
    lvgl.obj_set_pos(self.obj, x, y)
end

function Widget:setSize(w, h)
    lvgl.obj_set_size(self.obj, w, h)
end

function Widget:align(align)
    lvgl.obj_align(self.obj, nil, aligns[align] or 0, 0, 0)
end

function Widget:setClickable(on)
    lvgl.obj_set_click(self.obj, on)
end

function Widget:setEventHandler(cb)
    lvgl.obj_set_event_cb(self.obj, cb)
end

function Widget:setStyle(part, prop, val)
    local fn = "obj_set_style_" .. prop
    if lvgl[fn] then
        lvgl[fn](self.obj, parts[part] or 0, lvgl.STATE_DEFAULT, val)
    end
end

function Widget:addStyle(part, style)
    lvgl.obj_add_style(self.obj, parts[part] or 0, style);
end

function Widget:removeStyle(part, style)
    lvgl.obj_remove_style(self.obj, parts[part] or 0, style);
end

function Widget:createImage()
    local obj = lvgl.img_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Image)
end

function Widget:createLine()
    local obj = lvgl.line_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Line)
end

function Widget:createLabel()
    local obj = lvgl.label_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Label)
end

function Widget:createLed()
    local obj = lvgl.led_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Led)
end

function Widget:createSpinner()
    local obj = lvgl.spinner_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Spinner)
end

function Widget:createArc()
    local obj = lvgl.arc_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Arc)
end

function Widget:createBar()
    local obj = lvgl.bar_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Bar)
end

function Widget:createButton()
    local obj = lvgl.btn_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Button)
end

function Widget:createImageButton()
    local obj = lvgl.imgbtn_create(self.obj, nil)
    return setmetatable(Widget:new(obj), ImageButton)
end

function Widget:createTextArea()
    local obj = lvgl.textarea_create(self.obj, nil)
    return setmetatable(Widget:new(obj), TextArea)
end

function Widget:createSwitch()
    local obj = lvgl.switch_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Switch)
end

function Widget:createCheckbox()
    local obj = lvgl.checkbox_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Checkbox)
end

function Widget:createDropdown()
    local obj = lvgl.dropdown_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Dropdown)
end

function Widget:createSlider()
    local obj = lvgl.slider_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Slider)
end

function Widget:createSpinBox()
    local obj = lvgl.spinbox_create(self.obj, nil)
    return setmetatable(Widget:new(obj), SpinBox)
end

function Widget:createColorPicker()
    local obj = lvgl.cpicker_create(self.obj, nil)
    return setmetatable(Widget:new(obj), ColorPicker)
end

function Widget:createTable()
    local obj = lvgl.table_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Table)
end

function Widget:createChart()
    local obj = lvgl.chart_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Chart)
end

function Widget:createGauge()
    local obj = lvgl.gauge_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Gauge)
end

function Widget:createLineMeter()
    local obj = lvgl.linemeter_create(self.obj, nil)
    return setmetatable(Widget:new(obj), LineMeter)
end

function Widget:createContainer()
    local obj = lvgl.cont_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Container)
end

function Widget:createList()
    local obj = lvgl.list_create(self.obj, nil)
    return setmetatable(Widget:new(obj), List)
end

function Widget:createRoller()
    local obj = lvgl.roller_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Roller)
end

function Widget:createMsgBox()
    local obj = lvgl.msgbox_create(self.obj, nil)
    return setmetatable(Widget:new(obj), MsgBox)
end

function Widget:createTileView()
    local obj = lvgl.tileviwe_create(self.obj, nil)
    return setmetatable(Widget:new(obj), TileView)
end

function Widget:createTabView()
    local obj = lvgl.rabview_create(self.obj, nil)
    return setmetatable(Widget:new(obj), TabView)
end

function Widget:createWindow()
    local obj = lvgl.win_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Window)
end

function Widget:createObjectMask()
    local obj = lvgl.objmask_create(self.obj, nil)
    return setmetatable(Widget:new(obj), ObjectMask)
end

function Widget:createPage()
    local obj = lvgl.page_create(self.obj, nil)
    return setmetatable(Widget:new(obj), Page)
end

function Label:setText(str)
    lvgl.label_set_text(self.obj, str)
end

function Label:printf(fmt, ...)
    lvgl.label_set_text_fmt(self.obj, fmt, ...)
end

function Label:setAlign(align)
    lvgl.label_set_align(self.obj, label_aligns[align] or 0) -- /RIGHT/CENTER)
end

function Label:setRecolor(on)
    lvgl.label_set_recolor(self.obj, on);
end

function Label:setLongMode()
    lvgl.label_set_long_mode(self.obj, lvgl.LABEL_LONG_BREAK);
end

function Led:on()
    lvgl.led_on(self.obj);
end
function Led:off()
    lvgl.led_off(self.obj)
end
function Led:toggle()
    lvgl.led_toggle(self.obj)
end
function Led:setBright(bright)
    lvgl.led_set_bright(self.obj, bright);
end

function Arc:setBgAngles(start_angle, end_angle)
    lvgl.arc_set_bg_angles(self.obj, start_angle, end_angle)
end

function Arc:setRange(min, max)
    lvgl.arc_set_range(self.obj, min, max)
end

function Arc:setRotation(angle)
    lvgl.arc_set_rotation(self.obj, angle)
end

function Arc:setValue(value)
    lvgl.arc_set_value(self.obj, value)
end

function Arc:setType(type)
    lvgl.arc_set_type(self.obj, type)
end

function Bar:setRange(min, max)
    lvgl.bar_set_range(self.obj, min, max)
end

function Bar:setValue(value)
    lvgl.bar_set_value(self.obj, value, lvgl.ANIM_ON)
end

function Bar:setAnimateTime(ms)
    lvgl.bar_set_anim_time(self.obj, ms);
end

function Button:setLayout()
    lvgl.btn_set_layout(self.obj, lvgl.LAYOUT_CENTER)
end

function Button:setCheckable(on)
    lvgl.btn_set_checkable(self.obj, on)
end

function Button:toggle()
    lvgl.btn_toggle(self.obj)
end

function Button:setFit2(fit)
    lvgl.btn_set_fit2(self.obj, lvgl.FIT_NONE, fits[fit] or 0)
end

function Button:setText(str)
    if not self.label then
        self.label = lvgl.label_create(self.obj, nil)
    end
    lvgl.label_set_text(self.label, str)
end

function Checkbox:on(handler)
    lvgl.obj_set_event_cb(function(cb, event)
        if event == lvgl.EVENT_CLICKED then
            handler(lvgl.checkbox_is_checked(cb))
        end
    end)
end

function Checkbox:setText(str)
    lvgl.checkbox_set_text(self.obj, str)
end

function Checkbox:setChecked(on)
    lvgl.checkbox_set_checked(self.obj, on)
end
function Checkbox:setDisabled(on)
    lvgl.checkbox_set_disabled(self.obj, on)
end

function Checkbox:getState()
    return lvgl.checkbox_get_state(self.obj)
end

function Checkbox:setState(state)
    lvgl.checkbox_set_state(self.obj, state)
end

local Series = {}
Series.__index = Series

function Series:new(chart, series)
    return setmetatable({
        chart = chart,
        series = series
    }, Series)
end

function Series:SetNext(pt)
    lvgl.chart_set_next(self.chart, self.series, 90);
end

function Chart:setType()
    lvgl.chart_set_type(self.obj, lvgl.CHART_TYPE_LINE);
end

function Chart:addSeries()
    local series = lvgl.chart_add_series(self.obj, lvgl.color_make(0xFF, 0x00, 0x00));
    return Series:new(self.obj, series)
end

function Chart:refresh()
    lvgl.chart_refresh(self.obj);
end

function Container:setFit(fit)
    lvgl.cont_set_fit(self.obj, fits[fit] or 0);
end

function Container:setLayout()
    lvgl.cont_set_layout(self.obj, lvgl.LAYOUT_COLUMN_MID);
end

function ColorPicker:setType()
    lvgl.cpicker_set_type(self.obj, lvgl.CPICKER_TYPE_RECT) -- DISC
end

function ColorPicker:setColor(rgb)
    lvgl.cpicker_set_color(self.obj, rgb)
end

function ColorPicker:setColorMode()
    lvgl.cpicker_set_color_mode(self.obj, lvgl.CPICKER_COLOR_MODE_HUE) -- /SATURATION/VALUE)    
end

function ColorPicker:setKnobColored(on)
    lvgl.cpicker_set_knob_colored(self.obj, on)
end

function Dropdown:on(handler)
    lvgl.obj_set_event_cb(function(obj, event)
        if (event == lvgl.EVENT_VALUE_CHANGED) then
            handler(lvgl.dropdown_get_selected_str(obj, 20))
        end
    end)
end

function Dropdown:setOptions(options)
    lvgl.dropdown_set_options(self.obj, options)
end

function Dropdown:addOption(option, pos)
    lvgl.dropdown_add_option(self.obj, option, pos)
end

function Dropdown:setSelected(id)
    lvgl.dropdown_set_selected(self.obj, id)
end

function Dropdown:setDir()
    lvgl.dropdown_set_dir(self.obj, lvgl.DROPDOWN_DIR_LEFT) -- /RIGHT/UP/DOWN)
end

function Dropdown:setSymbol()
    lvgl.dropdown_set_symbol(self.obj, lvgl.SYMBOL_)
end

function Dropdown:setMaxHeight(height)
    lvgl.dropdown_set_max_height(self.obj, height)
end
function Dropdown:setShowSelected(on)
    lvgl.dropdown_set_show_selected(self.obj, on)
end
function Dropdown:setAnimateTime(ms)
    lvgl.dropdown_set_anim_time(self.obj, ms)
end
function Dropdown:open()
    lvgl.dropdown_open(self.obj, lvgl.ANIM_ON)
end
function Dropdown:close()
    lvgl.dropdown_close(self.obj, lvgl.ANIM_ON)
end

function Gauge:setNeedleCount(num, colors)
    lvgl.gauge_set_needle_count(self.obj, num, colors)
end

function Gauge:setValue(num, value)
    lvgl.gauge_set_value(self.obj, num, value)
end

function Gauge:setScale(angle, lines, labels)
    lvgl.gauge_set_scale(self.obj, angle, lines, labels)
end

function Gauge:setAngleOffset(angle)
    lvgl.gauge_set_angle_offset(self.obj, angle)
end

function Gauge:setRange(min, max)
    lvgl.gauge_set_range(self.obj, min, max)
end

function Gauge:setCriticalValue(value)
    lvgl.gauge_set_critical_value(self.obj, value)
end

function Image:setSrc(src)
    lvgl.img_set_src(self.obj, src)
end

function Image:setAutoSize(on)
    lvgl.img_set_auto_size(self.obj, on)
end

function Image:setOffsetX(x)
    lvgl.img_set_offset_x(self.obj, x)
end
function Image:setOffsetY(y)
    lvgl.img_set_offset_y(self.obj, y)
end
function Image:setZoom(factor)
    lvgl.img_set_zoom(self.obj, factor)
end
function Image:setAngle(angle)
    lvgl.img_set_angle(self.obj, angle)
end
function Image:setPivot(x, y)
    lvgl.img_set_pivot(self.obj, x, y)
end
function Image:setAtialias(on)
    lvgl.img_set_antialias(self.obj, on)
end
function Image:x()
    return lvgl.obj_get_x(self.obj)
end
function Image:y()
    return lvgl.obj_get_y(self.obj)
end
function Image:width()
    return lvgl.obj_get_width(self.obj)
end
function Image:height()
    lvgl.obj_get_height(self.obj)
end

function ImageButton:setReleased(src)
    lvgl.imgbtn_set_src(self.obj, lvgl.BTN_STATE_RELEASED, src);
end
function ImageButton:setPressed(src)
    lvgl.imgbtn_set_src(self.obj, lvgl.BTN_STATE_PRESSED, src);
end
function ImageButton:setCheckedReleased(src)
    lvgl.imgbtn_set_src(self.obj, lvgl.BTN_STATE_CHECKED_RELEASED, src);
end
function ImageButton:setCheckedPressed(src)
    lvgl.imgbtn_set_src(self.obj, lvgl.BTN_STATE_CHECKED_PRESSED, src);
end
function Image:setCheckable(on)
    lvgl.imgbtn_set_checkable(self.obj, on);
end
function ImageButton:setText(str)
    if not self.label then
        self.label = lvgl.label_create(self.obj, nil)
    end
    lvgl.label_set_text(self.label, str)
end

local Keyboard = {}
setmetatable(Keyboard, Widget)

local function kb_event_cb(keyboard, e)
    if e == lvgl.EVENT_DELETE then
        return
    end
    lvgl.keyboard_def_event_cb(kb, e);
    if (e == lvgl.EVENT_CANCEL) then
        lvgl.keyboard_set_textarea(kb, nil);
        lvgl.obj_del(kb);
        kb = nil
    end
end

local function ta_event_cb(ta_local, e)
    if (e == lvgl.EVENT_CLICKED and kb == nil) then
        kb_create()
    end
end

function Keyboard:new()
    kb = lvgl.keyboard_create(lvgl.scr_act(), nil);
    lvgl.keyboard_set_cursor_manage(kb, true);
    lvgl.obj_set_event_cb(kb, kb_event_cb);
    lvgl.keyboard_set_textarea(kb, ta);
end

function Line:setPoints()
    lvgl.line_set_points(lines, point_array, point_cnt)
end
function Line:setAutoSize(on)
    lvgl.line_set_auto_size(self.obj, on)
end

function List:addButton(image, str)
    lvgl.list_add_btn(self.obj, image, str)
end
function List:remove(index)
    lvgl.list_remove(self.obj, index)
end

function LineMeter:setRange(min, max)
    lvgl.linemeter_set_range(self.obj, min, max)
end
function LineMeter:setValue(value)
    lvgl.linemeter_set_value(self.obj, value)
end
function LineMeter:setScale(angle, line_num)
    lvgl.linemeter_set_scale(self.obj, angle, line_num)
end

function MsgBox:setText(str)
    lvgl.msgbox_set_text(self.obj, str)
end
function MsgBox:addButtons(strs)
    lvgl.msgbox_add_btns(self.obj, strs)
end
function MsgBox:StartAutoClose(ms)
    lvgl.msgbox_start_auto_close(self.obj, ms)
end
function MsgBox:StopAutoClose()
    lvgl.msgbox_stop_auto_close(self.obj)
end
function MsgBox:setAnimateTime(ms)
    lvgl.mbox_set_anim_time(self.obj, ms)
end

function Page:clean()
    lvgl.page_clean(self.obj)
end

function Roller:setOptions(options)
    lvgl.roller_set_options(self.obj, options, lvgl.ROLLER_MODE_NORMAL) -- /INFINITE)
end
function Roller:setSelected(id)
    lvgl.roller_set_selected(self.obj, id, lvgl.ANIM_ON) -- /OFF)
end
function Roller:getSelected()
    return lvgl.roller_get_selected(self.obj)
end
function Roller:setAlign(align)
    lvgl.roller_set_align(self.obj, aligns[align] or 0) -- /CENTER/RIGHT)
end
function Roller:setAnimateTime(ms)
    lvgl.roller_set_anim_time(self.obj, ms)
end
function Roller:setVisibleRows(num)
    lvgl.roller_set_visible_row_count(self.obj, num)
end

function Slider:setRange(min, max)
    lvgl.slider_set_range(self.obj, min, max)
end
function Slider:setValue(value)
    lvgl.slider_set_value(self.obj, value, lvgl.ANIM_ON) -- /OFF)
end
function Slider:setAnimateTime(ms)
    lvgl.slider_set_anim_time(self.obj, ms)
end

function SpinBox:setFormat(digit_count, separator_position)
    lvgl.spinbox_set_digit_format(self.obj, digit_count, separator_position)
end
function SpinBox:setRange(min, max)
    lvgl.spinbox_set_range(self.obj, min, max)
end
function SpinBox:setValue(value)
    lvgl.spinbox_set_value(self.obj, value, lvgl.ANIM_ON) -- /OFF)
end
function SpinBox:setAnimateTime(ms)
    lvgl.spinbox_set_anim_time(self.obj, ms)
end
function SpinBox:increment()
    lvgl.spinbox_increment(self.obj)
end
function SpinBox:decrement()
    lvgl.spinbox_decrement(self.obj)
end

function Spinner:setArcLength(deg)
    lvgl.spinner_set_arc_length(self.obj, deg)
end
function Spinner:setSpinTime(ms)
    lvgl.spinner_set_spin_time(self.obj, ms)
end
function Spinner:setType(type)
    -- lvgl.SPINNER_TYPE_SPINNING_ARC 旋转弧线，在顶部减速
    -- lvgl.SPINNER_TYPE_FILLSPIN_ARC 旋转弧线，在顶部放慢速度，但也伸展弧线
    -- lvgl.SPINNER_TYPE_CONSTANT_ARC 以恒定速度旋转
    lvgl.spinner_set_type(self.obj, type)
end
function Spinner:setDir()
    lvgl.spinner_set_dir(self.obj, lvgl.SPINNER_DIR_FORWARD) -- BACKWARD
end

function Switch:on()
    lvgl.switch_on(self.obj, lvgl.ANIM_ON);
end
function Switch:off()
    lvgl.switch_off(self.obj, lvgl.ANIM_ON)
end
function Switch:toggle()
    lvgl.switch_toggle(self.obj, lvgl.ANIM_ON)
end
function Switch:setAnimateTime(ms)
    lvgl.switch_set_anim_time(self.obj, ms)
end

function Table:setRows(cnt)
    lvgl.table_set_row_cnt(self.obj, cnt);
end
function Table:setColumns(cnt)
    lvgl.table_set_col_cnt(self.obj, cnt);
end
function Table:setCellAlign(row, col, align)
    lvgl.table_set_cell_align(self.obj, row, col, aligns[align] or 0);
end
function Table:setCellType(row, col, type)
    -- 1表头 2第一栏 3突出
    lvgl.table_set_cell_type(self.obj, row, col, type);
end
function Table:setCellValue(row, col, str)
    lvgl.table_set_cell_value(self.obj, row, col, str)
end
function Table:setColumnWidth(col, width)
    lvgl.table_set_col_width(self.obj, col, width)
end
function Table:setCellMergeRight(col, row, b)
    lvgl.table_set_cell_merge_right(self.obj, col, row, b)
end
function Table:setCellCrop(col, row, b)
    lvgl.table_set_cell_crop(self.obj, row, col, b)
end

function TabView:addTab(str)
    local tab = lvgl.tabview_add_tab(self.obj, str)
    return Widget:new(tab)
end
function TabView:setActive(id)
    lvgl.tabview_set_tab_act(self.obj, id, lvgl.ANIM_ON)
end
function TabView:setTabName(id, name)
    lvgl.tabview_set_tab_name(self.obj, id, name)
end
function TabView:setAnimateTime(ms)
    lvgl.tabview_set_anim_time(self.obj, ms)
end

function TextArea:addChar(c)
    lvgl.textarea_add_char(self.obj, c)
end
function TextArea:delChar()
    lvgl.textarea_del_char(self.obj)
end
function TextArea:addText(str)
    lvgl.textarea_add_text(self.obj, str)
end
function TextArea:setText(str)
    lvgl.textarea_set_text(self.obj, str)
end
function TextArea:getText()
    lvgl.textarea_get_text(self.obj)
end
function TextArea:setPlaceholder(str)
    lvgl.textarea_set_placeholder_text(self.obj, str)
end
function TextArea:setCursor(pos)
    lvgl.textarea_set_cursor_pos(self.obj, pos)
end
function TextArea:setOneLine(on)
    lvgl.textarea_set_one_line(self.obj, on)
end
function TextArea:setPwdMode(on)
    lvgl.textarea_set_pwd_mode(self.obj, on)
end
function TextArea:setTextAlign(align)
    lvgl.textarea_set_text_align(self.obj, aligns[align] or 0) -- /CENTER/RIGHT)
end
function TextArea:setMaxLength(num)
    lvgl.textarea_set_max_length(self.obj, num)
end
function TextArea:setSelectable(on)
    lvgl.textarea_set_text_sel(self.obj, on)
end

function Window:setTitle(str)
    lvgl.win_set_title(self.obj, str)
end
function Window:AddButtonRight()
    lvgl.win_add_btn_right(self.obj, lvgl.SYMBOL_CLOSE)
end

function ui.init(width, height)
    lvgl.init(width, height)
end

function ui.load(widget)
    lvgl.scr_load(widget.obj)
end

-- 默认控件
function ui.default()
    return Widget:new(lvgl.scr_act())
end

local Style = {}
Style.__index = Style

function Style:setRadius(r)
    lvgl.style_set_radius(self.style, r)
end
function Style:setBgColor(color)
    lvgl.style_set_bg_color(self.style, color)
end
function Style:setBorderColor(c)
    lvgl.style_set_border_color(self.style, c)
end
function Style:setBorderWidth(w)
    lvgl.style_set_border_width(self.style, w)
end

function ui.style()
    local style = lvgl.style_t()
    lvgl.style_init(style);
    setmetatable({
        style = style
    }, Style)

    -- TODO 不能直接这样用，LuatOS定义了 STYLE_XXX常量，用于设置
end

return ui
