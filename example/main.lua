local TERM_X, TERM_Y = term.getSize()

term.setBackgroundColour( 1 )
term.clear()

local tasks = {
    {"Launching Titanium"},
    {"Instantiating Application"},
    {"Loading TML"},
    {"Loading Theme"},
    {"Applying Theme"},
    {"Registering callbacks"},
    {"Starting parallel thread"},
    {"Done"}
}

local function printCentre( text, y, col )
    if col then term.setTextColour( col ) end

    term.setCursorPos( math.floor( TERM_X / 2 - ( #text / 2 ) ), y )
    term.clearLine()
    term.write( text )
end

local function completeTask( task )
    for i = 1, #tasks do
        if not tasks[ i ][ 2 ] then
            tasks[ i ][ 2 ] = os.clock()

            local y = 9
            for i = 1, #tasks do
                local done = tasks[ i ][ 2 ]
                printCentre( tasks[ i ][ 1 ] .. ( done and " ["..done.."]" or "" ), y, done and colours.green or ( pre and colours.cyan ) or 256 )

                pre, y = done, y + 1
            end

            return
        end
    end
end

sleep( 0 )
printCentre("Titanium GUI Framework", 4, colours.cyan)
printCentre("Example Application", 5, colours.lightGrey)
printCentre("Loading", TERM_Y - 1, 128)

dofile "build/titanium.lua" -- Run the compiled Titanium script
completeTask()

--[[
    An Application instance is the starting point of a Titanium application. It accepts 4 arguments: x, y, width and height.
    The default position and size was fine for my use case, so I passed no arguments inside the brackets.

    I did however want to adjust some other properties of the Application, so for that I used the `set` function and passed a
    key-value table. The key being the name of the property and the value being the value of the property.

    `:set` is available on all nodes as well and returns the object you called it on (in this case, Application) so you can chain other functions
    after it.
]]
Manager = Application():set {
    colour = 128,
    backgroundColour = 1,
    terminatable = true
}

completeTask()

--[[
    TML is a custom markup language for Titanium aiming to drastically increase productivity and descrease the amount of Lua you write when
    designing your UI.

    The import function loads the TML file and adds all the nodes generated to `Manager`, which is our Application instance.
]]
Manager:importFromTML "example/ui/master.tml"
completeTask()

--[[
    This local is a table that contains some commonly used assets. `Manager:query` allows us to use CSS like selectors
    to search all the nodes inside of our application and return the result.

    To speed the program up, we only query these things once and store the result in `app`.
]]
local app = {
    -- Here we import our theme file, this is the same sytnax as TML however it doesn't create nodes but instead allows styling (think, a CSS file).
    masterTheme = Theme.fromFile( "masterTheme", "example/ui/master.theme" ),

    -- Grab our page container which was created in our TML file. This page container has two pages, which we will get into later
    pages = Manager:query "PageContainer".result[1],

    -- Store some commonly used assets for our animated sidebar
    sidePane = {
        pane = Manager:query "Container#pane",
        hotkeys = Manager:query "Label.hotkey_part",

        left = Manager:query "Label#left.hotkey_part",
        right = Manager:query "Label#right.hotkey_part"
    },
}

completeTask()

-- Using our `app` local, switch the current page to 'main'. The page named 'main' which is defined in our TML file is now visible on the screen
app.pages:selectPage "main"
app.pages.animationDuration = "${#animationSlider}.value * 0.15"

-- We already imported our theme file inside our `app` local, however we haven't added it to our application yet. Doing so means the theme file will be applied
Manager:addTheme( app.masterTheme )
completeTask()

--[[
    This is the first time we have used ':on', so what exactly does it do?

    First, we query the application for something with an id of 'exit_button'. Titanium will search your application and return a
    `NodeQuery` instance which we can use to access the results. Instead of accessing the results directly, we use the NodeQuery
    shortcut feature to apply changes straight away.

    Calling ':on' tells Titanium to bind an event listener to all the nodes it found, in our case this is just one. We tell Titanium 'on trigger, run this function'.
    Trigger means the node was... triggered. In this case, the node we got is a Button so it means when the button is clicked.
]]
local exit_button = Manager:query "#exit_button"
exit_button:on( "trigger", function( self )
    -- Our exit button has been clicked. This means the button is enabled, and therefore the 'yes' checkbox was selected
    Manager:stop()
end)

--[[
    These two binds will enable/disable the button depending on the one clicked.

    This means that the exit button will only become enabled when the '#yes_rating' radio button is clicked, preventing the button
    from closing the program until the user 'allows exit'.
]]
Manager:query "#yes_rating":on( "select", function() exit_button:set{ enabled = true } end)
Manager:query "#no_rating":on( "select", function() exit_button:set{ enabled = false } end)

--[[
    Much like above, we grab our node with an id 'name_display'. In our TML file, we can see that is a label - a simple node for displaying a line of text
    We also query the application for a node with id 'name_input', which in our case is an 'Input' node. We bind a trigger event (when enter is pressed inside the input) to
    the node and pass a function for Titanium to call when the input is triggered.
]]
nameDisplay = Manager:query "#name_display"
Manager:query "#name_input":on("trigger", function( self, value, selectedValue )
    --[[
        Input has been triggered, lets do some stuff!

        First, we set the 'hasValue' class of our name display label to true IF the user has enetered some text. If they haven't, the class is removed.
        This class is used in our Theme file to change the colour of the label depending on whether or not the user entered text.
    ]]
    nameDisplay:setClass( "hasValue", value ~= "" )

    --[[
        Next, we get the label from our node query (using .result[1], which means get the first result) and set it's text value (.text = "text value") to a value.
        This value will be 'No entered text' if the value the user entered is blank (empty string). If the user did enter something we check if the value exceeds 40
        characters in length.

        If it does exceed this length, we trim it down to 40 characters and stick '...' on the end to show that it has been trimmed. If the text does NOT exceed this
        limit, it is simply displayed as it.
    ]]
    nameDisplay.result[1].text = ( not value or value == "" ) and "No entered text" or ( #value > 40 and value:sub( 1, 40 ).."..." or value )

    -- if the user selected text (shift-<arrowKey>), we display it here. If they did not, we display 'No selected text'
    Manager:query "#selected_name_display".result[1].text = selectedValue and "Selected: "..selectedValue or "No selected text"
end)

-- A local variable used to keep track of the current theme
local themed = true
Manager:query "#toggle":on("trigger", function( self )
    -- When the button with id 'toggle' is clicked, toggle the theme in the application.
    themed = not themed
    if not themed then Manager:removeTheme "masterTheme"
    else Manager:addTheme( app.masterTheme ) end
end)

--[[
    Here we handle the animation of the side bar. We localise `app.sidePane` to just `sidePane` for simplicities sake.

    When this function is called, it will be passed a value. This value will either be true, or something else (the instance of the application that invoked it).
    If the value is true (not truthy), we know it was called from the hotkey function that runs when `ctrl-p` is activated. Because of this, we light up the hotkey
    display (under the pane toggle button) to show that the hotkey worked by adding the 'active' class to all sections of the hotkey.
]]
local sidePane, paneStatus = app.sidePane
local function paneToggle( isKey )
    paneStatus = not paneStatus

    if isKey == true then sidePane.hotkeys:addClass "active" end

    --[[
        Start the animation. Depending on whether or not the pane is animating out or in, different values are passed.

        If the pane is animating into view, the target X is 31, with a duration of 0.15s and an easing of 'outSine'.
        If the pane is animating out of view, the target X is 52, with a duration of 0.2s and an easing of 'inQuad'
    ]]
    sidePane.pane:animate("sidePaneAnimation", "X", paneStatus and 31 or 52, paneStatus and 0.15 or 0.2, paneStatus and "outSine" or "inQuad", function()
        -- This function is run when the animation is complete. We remove the highlight on the hotkey combination to return it back to normal colour
        sidePane.hotkeys:removeClass "active"
    end)
end


-- The 'Save Settings' button was clicked inside the side bar. Close the sidebar by calling `paneToggle`
Manager:query"#config_save":on("trigger", function( self )
    if paneStatus then
        paneToggle()
    end
end)

-- The 'Shell' or 'Return' button was clicked (depending on the selected page). Swap the page.
-- When the page swaps, different content will be displayed. This is defined in the TML file using `<Page name="main">` and `<Page name="console">`
Manager:query ".page_change":on("trigger", function( self )
    app.pages:selectPage( self.targetPage )
end)

Manager:registerHotkey("close", "leftCtrl-leftShift-t", Manager.stop) -- Setup a hotkey that makes closing the program quicker
Manager:query "#pane_toggle":on("trigger", paneToggle) -- When the pane toggle button is clicked... toggle the pane
Manager:registerHotkey("paneToggle", "leftCtrl-p", function()
    -- If the hotkey to toggle the pane was clicked, toggle it and pass the 'true' value (see the comments above function paneToggle)
    paneToggle( true )
end)

completeTask()

--[[
    This thread runs alongside the Application thread, allowing parallel programming from inside Titanium.

    This thread sets a loop that yields for events. When an event is received, it is a Titanium event. We check if the event is a 'key' event.
    If the key was pressed down we highlight that part of the hotkey by adding the held class to the label.

    If the key was released, we remove the class. The Theme file uses this theme to highlight the label when the 'held' class is present
]]
Manager:addThread(Thread(function()
    while true do -- Wait for events indefinitely
        local event = coroutine.yield() -- Wait for events
        if event.main == "KEY" then -- Is it a key event? (key, key_up)
            if event.keyName == "leftCtrl" then -- The user pressed OR released the 'leftCtrl' key
                sidePane.left:setClass( "held", event.sub == "DOWN" ) -- Set the class 'held' on the 'leftCtrl' label if the user pressed the key. Otherwise, remove the class
            elseif event.keyName == "p" then -- The user pressed OR released the 'p' key
                sidePane.right:setClass( "held", event.sub == "DOWN" ) -- Set the class 'held' on the 'p' label if the user pressed the key. Otherwise, remove the class
            end
        end
    end
end, true)) -- This true value tells Titanium to give the thread Titanium events, NOT CC events.

completeTask()

-- On the second page of the Application we have a terminal node that can be accessed by pressing the 'Shell' button in the top right.
-- We start the terminal by loading the '/rom/programs/shell' program and setting that as the terminal 'chunk'. The terminal node is now running
-- the shell and we can use it just like a normal shell
Manager:query "Terminal#shell":set { chunk = function() select( 1, loadfile "/rom/programs/shell" )() end }

--[[
    Another way of waiting for events is using the ':on' function. Simply provide the CC event name (mouse_click, key_up, char, paste) as the first argument
    and a function to run as the second.

    In this function we spawn an example context menu when the user right clicks on empty space. If the user right clicks on a node that uses the
    click event, the `event.handled` value will be true.
]]
Manager:on("mouse_click", function( self, event )
    if event.button == 2 and not event.handled then -- Only proceed if the button used was the right click, and the event wasn't used by any nodes
        event.handled = true
        if context then
            Manager:removeNode( context )
        end
        context = Manager:addNode( ContextMenu({
            {"button", "Copy", function( self ) error( "Button: " .. self.text) end},
            {"button", "Paste", function( self ) error( "Button: " .. self.text) end},
            {"rule"},
            {"menu", "More \16", {
                {"button", "Move", function( self ) error( "Button: " .. self.text) end},
                {"button", "Delete", function( self ) error( "Button: " .. self.text) end},
                {"menu", "More \16", {
                    {"button", "Rename", function( self ) error( "Button: " .. self.text) end},
                    {"button", "Remove", function( self ) error( "Button: " .. self.text) end},
                }}
            }}
        }, event.X, event.Y ):set{ backgroundColour = colours.yellow, colour = 128 } )
    end
end)

-- We are ready to go. Any code after this function will not be executed until the application closes.
completeTask()
Manager:start()
