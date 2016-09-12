dofile "build/titanium.lua" -- Run the compiled Titanium script

Manager = Application():set {
    colour = 128,
    backgroundColour = 1,
    -- terminatable = true
}

Manager:importFromTML "example/ui/master.tml"
local app = {
    masterTheme = Theme.fromFile( "masterTheme", "example/ui/master.theme" ),
    sidePane = {
        pane = Manager:query "Container#pane",
        hotkeys = Manager:query "Label.hotkey_part",

        left = Manager:query "Label#left.hotkey_part",
        right = Manager:query "Label#right.hotkey_part"
    },
}

Manager:addTheme( app.masterTheme )
Manager:getNode "exit_button":on("trigger", function( self )
    if RadioButton.getValue "rating" == "yes" then
        Manager:stop()
    end
end)

Manager:getNode "name_input":on("trigger", function( self, value, selectedValue )
    local nameDisplay = Manager:getNode "name_display"
    nameDisplay:setClass( "hasValue", value ~= "" )

    nameDisplay.text = ( not value or value == "" ) and "No entered text" or ( #value > 40 and value:sub( 1, 40 ).."..." or value )
    Manager:getNode "selected_name_display".text = selectedValue and "Selected: "..selectedValue or "No selected text"
end)

local themed = true
Manager:getNode "toggle":on("trigger", function( self )
    themed = not themed
    if not themed then Manager:removeTheme "masterTheme"
    else Manager:addTheme( app.masterTheme ) end
end)

local sidePane, paneStatus = app.sidePane
local function paneToggle( isKey )
    paneStatus = not paneStatus

    if isKey == true then sidePane.hotkeys:addClass "active" end
    sidePane.pane:animate("sidePaneAnimation", "X", paneStatus and 31 or 52, paneStatus and 0.15 or 0.2, paneStatus and "outSine" or "inQuad", function()
        sidePane.hotkeys:removeClass "active"
    end)
end

Manager:getNode( "config_save", true ):on("trigger", function( self )
    if paneStatus then
        paneToggle()
    end
end)

Manager:registerHotkey("close", "leftCtrl-leftShift-t", Manager.stop)
Manager:getNode "pane_toggle":on("trigger", paneToggle)

Manager:registerHotkey("paneToggle", "leftCtrl-p", function()
    paneToggle( true )
end)

Manager:addThread(Thread(function()
    while true do
        local event = coroutine.yield()
        if event.main == "KEY" then
            if event.keyName == "leftCtrl" then
                sidePane.left:setClass( "held", event.sub == "DOWN" )
            elseif event.keyName == "p" then
                sidePane.right:setClass( "held", event.sub == "DOWN" )
            end
        end
    end
end, true))

Manager:start()
