dofile "build/titanium.lua" -- Run the compiled Titanium script

Manager = Application():set {
    colour = 128,
    backgroundColour = 1,
    terminatable = true
}

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

local themed = false
Manager:getNode "toggle":on("trigger", function( self )
    themed = not themed
    if not themed then Manager:removeTheme "masterTheme"
    else Manager:importTheme( "masterTheme", "example/ui/master.theme" ) end
end)

Manager:importTheme( "masterTheme", "example/ui/master.theme" )
local pane, paneStatus, currentAnimation = Manager:getNode "pane"
Manager:getNode "pane_toggle":on("trigger", function()
    paneStatus = not paneStatus
    if currentAnimation then Manager:removeAnimation( currentAnimation ) end

    if paneStatus then
        currentAnimation = pane:animate("X", 32, 0.6, "outExpo") -- Appears on screen fast then slows down to a stop rapidly
    else
        currentAnimation = pane:animate("X", 52, 0.2, "inQuad") -- Starts slow and then accelerates off the screen
    end
end)
Manager:start()
