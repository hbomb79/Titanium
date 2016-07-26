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

local pane, paneStatus, currentAnimation = Manager:getNode "pane"
Manager:getNode "pane_toggle":on("trigger", function()
    paneStatus = not paneStatus
    if currentAnimation then Manager:removeAnimation( currentAnimation ) end

    currentAnimation = pane:animate("X", paneStatus and 32 or 52, paneStatus and 0.6 or 0.2, paneStatus and "outExpo" or "inQuad")
end)
Manager:start()
