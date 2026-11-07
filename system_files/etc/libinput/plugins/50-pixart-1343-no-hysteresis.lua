-- SPDX-License-Identifier: MIT
--
-- Disable libinput's touchpad hysteresis on the PixArt 093A:1343 haptic
-- touchpad (Framework Laptop 13 Pro).
--
-- libinput turns hysteresis on at runtime once it sees a single finger wobble
-- left-right-left, then ignores every motion smaller than resolution/4
-- (6 units = 0.25 mm on this pad) for the rest of the session. That swallows
-- very fine cursor movements.
--
-- Shipped in the tishy image at /etc/libinput/plugins/. Needs the patched
-- libinput from the rain1094/libinput-tishy COPR: stock libinput lets wobble
-- detection turn hysteresis back on. Plugins load when the compositor starts.

libinput:register({1})

libinput:connect("new-evdev-device", function(device)
    local info = device:info()
    if info.vid == 0x093A and info.pid == 0x1343 and
       device:udev_properties()["ID_INPUT_TOUCHPAD"] then
        libinput:log_info("Disabling touchpad hysteresis on " .. device:name())
        device:disable_feature("touchpad-hysteresis")
    end
end)
