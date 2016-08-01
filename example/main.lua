dofile "build/titanium.lua" -- Run the compiled Titanium script

Manager = Application():set {
    colour = 128,
    backgroundColour = 1,
    terminatable = true
}

local masterTheme = Theme.fromFile( "masterTheme", "example/ui/master.theme" )
Manager:addTheme( masterTheme )

Manager:importFromTML "example/ui/master.tml"
Manager:getNode "exit_button":on("trigger", function( self )
    if RadioButton.getValue "rating" == "yes" then
        Manager:stop()
    end
end)

Manager:getNode "name_input":on("trigger", function( self, value, selectedValue )
    local nameDisplay = Manager:getNode "name_display"
    if value == "" then
        nameDisplay:removeClass "hasValue"
    else
        nameDisplay:addClass "hasValue"
    end

    nameDisplay.text = ( not value or value == "" ) and "No entered text" or ( #value > 40 and value:sub( 1, 40 ).."..." or value )
    Manager:getNode "selected_name_display".text = selectedValue and "Selected: "..selectedValue or "No selected text"
end)

local themed = true
Manager:getNode "toggle":on("trigger", function( self )
    themed = not themed
    if not themed then Manager:removeTheme "masterTheme"
    else Manager:addTheme( masterTheme ) end
end)

local leftCtrlLabel, pCharLabel, hyphenSeperator = Manager:getNode "left_ctrl_label", Manager:getNode "p_char_label", Manager:getNode "hyphen_seperator"
local pane, paneStatus, currentAnimation = Manager:getNode "pane"
local function paneToggle( isKey )
    paneStatus = not paneStatus
    if currentAnimation then Manager:removeAnimation( currentAnimation ) end

    if isKey == true then
        leftCtrlLabel:addClass "active"
        hyphenSeperator:addClass "active"
        pCharLabel:addClass "active"
    end

    currentAnimation = pane:animate("X", paneStatus and 32 or 52, paneStatus and 0.4 or 0.2, paneStatus and "outSine" or "inQuad", function()
        leftCtrlLabel:removeClass "active"
        pCharLabel:removeClass "active"
        hyphenSeperator:removeClass "active"
    end)
end

Manager:registerHotkey("close", "leftCtrl-leftShift-t", function()
    Manager:stop()
end)

Manager:getNode "pane_toggle":on("trigger", function() paneToggle() end)
Manager:registerHotkey("paneToggle", "leftCtrl-p", function()
    paneToggle( true )
end)

Manager:addThread(Thread(function()
    while true do
        local event = coroutine.yield()
        if event.main == "KEY" then
            local down = event.sub == "DOWN"
            if event.keyName == "leftCtrl" then
                leftCtrlLabel[ down and "addClass" or "removeClass" ]( leftCtrlLabel, "held" )
            elseif event.keyName == "p" then
                pCharLabel[ down and "addClass" or "removeClass" ]( pCharLabel, "held" )
            end
        end
    end
end, true))

Manager:start()
