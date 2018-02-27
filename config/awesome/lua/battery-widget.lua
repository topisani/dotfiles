local awful = require("awful")
local beautiful = require("beautiful")
local naughty = require("naughty")
local wibox = require("wibox")
local watch = require("awful.widget.watch")

local HOME = os.getenv("HOME")

-- only text
local text = wibox.widget {
    id = "txt",
    font = "Play 5",
    widget = wibox.widget.textbox
}

-- mirror the text, because the whole widget will be mirrored after
local mirrored_text = wibox.container.mirror(text, { horizontal = true })

-- mirrored text with background
local mirrored_text_with_background = wibox.container.background(mirrored_text)

local batteryarc = wibox.widget {
    mirrored_text_with_background,
    max_value = 1,
    rounded_edge = true,
    thickness = 2,
    start_angle = 4.71238898, -- 2pi*3/4
    forced_height = 16,
    forced_width = 16,
    bg = "#ffffff11",
    paddings = 2,
    widget = wibox.container.arcchart,
    set_value = function(self, value)
        self.value = value
    end,
}

-- mirror the widget, so that chart value increases clockwise
batteryarc_widget = wibox.container.mirror(batteryarc, { horizontal = true })
battery_widget = wibox.container.margin(batteryarc_widget, 2, 6)

function update_widgets(widget, stdout, stderr, exitreason, exitcode)
    local batteryType
    local _, status, charge_str, time = string.match(stdout, '(.+): (%a+), (%d?%d%d)%%,? ?.*')
    local charge = tonumber(charge_str)
    widget.value = charge / 100
    if status == 'Charging' then
        mirrored_text_with_background.bg = beautiful.widget_green
        mirrored_text_with_background.fg = beautiful.widget_black
    else
        mirrored_text_with_background.bg = beautiful.widget_transparent
        mirrored_text_with_background.fg = beautiful.widget_main_color
    end

    if charge < 15 then
        batteryarc.colors = { beautiful.widget_red }
        if status == 'Charging' then
           destroy_battery_warning()
        else
           show_battery_warning(charge)
        end
    elseif charge > 15 and charge < 40 then
        batteryarc.colors = { beautiful.widget_yellow }
        destroy_battery_warning()
    else
        batteryarc.colors = { beautiful.widget_main_color }
        destroy_battery_warning()
    end
    text.text = charge
end

watch("acpi", 10,
   update_widgets,
   batteryarc)

-- Popup with battery info
-- One way of creating a pop-up notification - naughty.notify
local notification
function show_battery_status()
   awful.spawn.easy_async([[bash -c 'acpi']],
      function(stdout, _, _, _)
         update_widgets(batteryarc, stdout)
         notification = naughty.notify {
            text = stdout,
            title = "Battery status",
            timeout = 5,
            hover_timeout = 0.5,
            width = 200,
         }
      end)
end


batteryarc:connect_signal("mouse::enter", function() show_battery_status() end)
batteryarc:connect_signal("mouse::leave", function() naughty.destroy(notification) end)

-- Alternative to naughty.notify - tooltip. You can compare both and choose the preferred one

--battery_popup = awful.tooltip({objects = {battery_widget}})

-- To use colors from beautiful theme put
-- following lines in rc.lua before require("battery"):
-- beautiful.tooltip_fg = beautiful.fg_normal
-- beautiful.tooltip_bg = beautiful.bg_normal

local warning_notification = nil
local last_warn_percentage = nil
--[[ Show warning notification ]]
function show_battery_warning(percentage)
   if last_warn_percentage == percentage then
      return
   end
   naughty.destroy(warning_notification)
   warning_notification = naughty.notify {
      icon = HOME .. "/.config/awesome/images/battery_warning.png",
      icon_size = 100,
      title = string.format("Battery is at %d%%", percentage),
      text = "Help",
      timeout = 0,
      position = "top_right",
      ignore_suspend = true,
      ontop = true,
      bg = "#F06060",
      fg = "#EEE9EF",
      width = 300,
   }
   last_warn_percentage = percentage
end

function destroy_battery_warning()
   if (warning_notification) then
      naughty.destroy(warning_notification)
   end
end
