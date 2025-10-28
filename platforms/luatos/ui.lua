local ui = {}


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

function Widget:align()
    lvgl.obj_align(self.obj, nil, lvgl.ALIGN_CENTER, 0, 0)
end

function Widget:setClickable(on)
    lvgl.obj_set_click(self.obj, on)
end

function Widget:setEventHandler(cb)
    lvgl.obj_set_event_cb(self.obj, cb)
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

function Label:setAlign()
    lvgl.label_set_align(self.obj, lvgl.LABEL_ALIGN_LEFT) -- /RIGHT/CENTER)
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

function Button:setFit2()
    lvgl.btn_set_fit2(self.obj, lvgl.FIT_NONE, lvgl.FIT_TIGHT)
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

function Container:setFit()
    lvgl.cont_set_fit(self.obj, lvgl.FIT_TIGHT);
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
function Roller:setAlign()
    lvgl.roller_set_align(self.obj, lvgl.LABEL_ALIGN_LEFT) -- /CENTER/RIGHT)
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
function Table:setCellAlign(row, col)
    lvgl.table_set_cell_align(self.obj, row, col, lvgl.LABEL_ALIGN_CENTER);
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
function TextArea:setTextAlign()
    lvgl.textarea_set_text_align(self.obj, lvgl.LABEL_ALIGN_LET) -- /CENTER/RIGHT)
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


return ui