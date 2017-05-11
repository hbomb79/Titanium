--[[
    Event declaration
    =================

    Titanium needs to know what class types to spawn when an event is spawned, for flexibility this can be edited whenever you see fit. The matrix
    starts blank, so we define basic events here. (on event type 'key', spawn instance of type 'value')
]]
Event.static.matrix = {
    mouse_click = MouseEvent,
    mouse_drag = MouseEvent,
    mouse_up = MouseEvent,
    mouse_scroll = MouseEvent,

    key = KeyEvent,
    key_up = KeyEvent,

    char = CharEvent
}

--[[
    Image Parsing
    =============

    Titaniums Image class parses image files based on their extension, two popular formats (nfp and default) are supported by default, however this can be expanded like you see here.
    These functions are expected to return the dimensions of the image and, a buffer (2D table) of pixels to be drawn directly to the images canvas. Pixels that do not exist in the image
    need not be accounted for, Titanium will automatically fill those as 'blank' pixels by setting them as 'transparent'.

    See the default functions below for good examples of image parsing.
]]

Image.setImageParser("", function( stream ) -- Default CC images, no extension
    -- Break image into lines, find the maxwidth of the image (the length of the longest line)
    local hex = TermCanvas.static.hex
    width, lines, pixels = 1, {}, {}
    for line in stream:gmatch "([^\n]*)\n?" do
        width = math.max( width, #line )
        lines[ #lines + 1 ] = line
    end

    -- Iterate each line, forming a buffer of pixels with missing information (whitespace) being left nil
    for l = 1, #lines do
        local y, line = width * ( l - 1 ), lines[ l ]

        for i = 1, width do
            local colour = hex[ line:sub( i, i ) ]
            pixels[ y + i ] = { " ", colour, colour }
        end
    end

    return width, #lines, pixels
end).setImageParser("nfp", function( stream ) -- NFP images, .nfp extension
    --TODO: Look into nfp file format and write parser
end)

--[[
    Shader Setup
    ============

    WIP
]]
Canvas.registerShader( "darken", { [1] = 256, [2] = 16384, [4] = 1024, [8] = 512, [16] = 2, [32] = 8192, [64] = 4, [128] = 32768, [256] = 128, [512] = 2048, [1024] = 16384, [2048] = 4096, [4096] = 32768, [8192] = 128, [16384] = 128, [32768] = 32768 } )
Canvas.registerShader( "lighten", { [1] = 1, [2] = 16, [4] = 64, [8] = 1, [16] = 1, [32] = 16, [64] = 1, [128] = 256, [256] = 1, [512] = 8, [1024] = 64, [2048] = 8, [4096] = 256, [8192] = 32, [16384] = 2, [32768] = 256 } )
Canvas.registerShader( "inverse", { [1] = 32768, [2] = 2048, [4] = 32, [8] = 4096, [16] = 1024, [32] = 1024, [64] = 8192, [128] = 256, [256] = 128, [512] = 4096, [1024] = 32, [2048] = 2, [4096] = 8, [8192] = 4, [16384] = 512, [32768] = 1 } )
Canvas.registerShader( "greyscale", { [1] = 1, [2] = 256, [4] = 256, [8] = 256, [16] = 1, [32] = 256, [64] = 256, [128] = 128, [256] = 256, [512] = 128, [1024] = 128, [2048] = 128, [4096] = 32768, [8192] = 128, [16384] = 128, [32768] = 32768 } )

--[[
    Projector Setup
    ===============

    Before projectors can be used, modes for them must be registered. For example in order to project/mirror a container to a monitor a mode
    specifically designed to project content to a monitor must be created (see below for the monitor projector mode).

    Every projector mode must be registered via 'Projector.registerMode', passing a table of configuration keys. The table has to contain:
        - mode (string) - The name of the 'mode' used when creating a projector
        - init (function) - Executed automatically when this mode is selected inside a projector
        - draw (function) - Executed when any of the mirrors have changed, requiring a redraw of the projector

    Optional configuration keys:
        - eventDispatcher (function) - Executed automatically when an event is caught by an attached mirror.
        - targetResolver (function) - Executed automatically when the mode is changed, or the target is changed. Can be used to parse the target value (return the new target [becomes resolvedTarget])

]]

Projector.registerMode {
    mode = "monitor",
    draw = function( self )
        local targets, t = self.resolvedTarget
        local focused = self.application and self.application.focusedNode and self.containsFocus

        local scale = self.textScale and XMLParser.convertArgType( self.textScale, "number" ) or 1

        local blink, X, Y, colour
        if focused then
            blink, X, Y, colour = focused[ 1 ], focused[ 2 ], focused[ 3 ], focused[ 4 ]
        end

        local old = term.current()
        for i = 1, #targets do
            t = targets[ i ]
            t.setTextScale( scale )

            term.redirect( t )

            self.canvas:draw( true )

            term.setCursorBlink( blink or false )
            if blink then
                term.setCursorPos( X or 1, Y or 1 )
                term.setTextColour( colour or 32768 )
            end
        end

        term.redirect( old )
    end,
    eventDispatcher = function( self, event )
        if event.handled or not self.resolvedTarget[ event.data[ 2 ] ] or event.main ~= "MONITOR_TOUCH" then return end

        local function dispatch( event )
            event.projectorOrigin = true

            local mirrors = self.mirrors
            local oX, oY = event.X, event.Y
            for i = 1, #mirrors do
                local mirror = mirrors[ i ]
                local pX, pY = mirror.projectX, mirror.projectY
                local offset = pX or pY

                if offset then event.X, event.Y = oX + ( mirror.X - ( pX or 0 ) ), oY + ( mirror.Y - ( pY or 0 ) ) end
                mirror:handle( event )
                if offset then event.X, event.Y = oX, oY end
            end
        end

        local X, Y = event.data[ 3 ], event.data[ 4 ]
        dispatch( MouseEvent( "mouse_click", 1, X, Y ) )
        self.application:schedule( function()
            dispatch( MouseEvent( "mouse_up", 1, X, Y ) )
        end, 0.1 )
    end,
    targetResolver = function( self, target )
        if not type( target ) == "string" then
            return error( "Failed to resolve target '"..tostring( target ).."' for monitor projector mode. Expected number, got '"..type( target ).."'")
        end

        local targets = {}
        for t in target:gmatch "%S+" do
            if not targets[ t ] then
                targets[ #targets + 1 ] = peripheral.wrap( t ) or error("Failed to resolve targets for projector '"..self.name.."'. Invalid target '"..t.."'")
                targets[ t ] = true
            end
        end

        self.width, self.height = targets[ 1 ].getSize()

        return targets
    end
}

--[[
    Tween setup
    ===========

    The following blocks of code define the functions that will be invoked when an animation that used that type of easing is updated. These functions
    are adjusted versions (the algorithm has remained the same, however code formatting and variable names are largely changed to match Titanium) of
    the easing functions published by kikito on GitHub. Refer to 'LICENSE' in this project root for more information (and Enrique's license).

    The functions are passed 4 arguments, these arguments are listed below:
    - clock: This argument contains the current clock time of the Tween being updated, this is used to tell how far through the animation we are (in seconds)
    - initial: The value of the property being animated at the instantiation of the tween. This is usually added as a Y-Axis transformation.
    - change: The difference of the initial and final property value. ie: How much the value will have to change to match the final from where it was as instantiation.
    - duration: The total duration of the running Tween.

    Certain functions are passed extra arguments. The Tween class doesn't pass these in, however custom animation engines could invoke these easing functions
    through `Tween.static.easing.<easingType>`.
]]

local abs, pow, asin, sin, cos, sqrt, pi = math.abs, math.pow, math.asin, math.sin, math.cos, math.sqrt, math.pi
local easing = Tween.static.easing
-- Linear easing function
Tween.addEasing("linear", function( clock, initial, change, duration )
    return change * clock / duration + initial
end)

-- Quad easing functions
Tween.addEasing("inQuad", function( clock, initial, change, duration )
    return change * pow( clock / duration, 2 ) + initial
end).addEasing("outQuad", function( clock, initial, change, duration )
    local clock = clock / duration
    return -change * clock * ( clock - 2 ) + initial
end).addEasing("inOutQuad", function( clock, initial, change, duration )
    local clock = clock / duration * 2
    if clock < 1 then
        return change / 2 * pow( clock, 2 ) + initial
    end

    return -change / 2 * ( ( clock - 1 ) * ( clock - 3 ) - 1 ) + initial
end).addEasing("outInQuad", function( clock, initial, change, duration )
    if clock < duration / 2 then
        return easing.outQuad( clock * 2, initial, change / 2, duration )
    end

    return easing.inQuad( ( clock * 2 ) - duration, initial + change / 2, change / 2, duration)
end)

-- Cubic easing functions
Tween.addEasing("inCubic", function( clock, initial, change, duration )
    return change * pow( clock / duration, 3 ) + initial
end).addEasing("outCubic", function( clock, initial, change, duration )
    return change * ( pow( clock / duration - 1, 3 ) + 1 ) + initial
end).addEasing("inOutCubic", function( clock, initial, change, duration )
    local clock = clock / duration * 2
    if clock < 1 then
        return change / 2 * clock * clock * clock + initial
    end

    clock = clock - 2
    return change / 2 * (clock * clock * clock + 2) + initial
end).addEasing("outInCubic", function( clock, initial, change, duration )
    if clock < duration / 2 then
        return easing.outCubic( clock * 2, initial, change / 2, duration )
    end

    return easing.inCubic( ( clock * 2 ) - duration, initial + change / 2, change / 2, duration )
end)

-- Quart easing functions
Tween.addEasing("inQuart", function( clock, initial, change, duration )
    return change * pow( clock / duration, 4 ) + initial
end).addEasing("outQuart", function( clock, initial, change, duration )
    return -change * ( pow( clock / duration - 1, 4 ) - 1 ) + initial
end).addEasing("inOutQuart", function( clock, initial, change, duration )
    local clock = clock / duration * 2
    if clock < 1 then
        return change / 2 * pow(clock, 4) + initial
    end

    return -change / 2 * ( pow( clock - 2, 4 ) - 2 ) + initial
end).addEasing("outInQuart", function( clock, initial, change, duration )
    if clock < duration / 2 then
        return easing.outQuart( clock * 2, initial, change / 2, duration )
    end

    return easing.inQuart( ( clock * 2 ) - duration, initial + change / 2, change / 2, duration )
end)

-- Quint easing functions
Tween.addEasing("inQuint", function( clock, initial, change, duration )
    return change * pow( clock / duration, 5 ) + initial
end).addEasing("outQuint", function( clock, initial, change, duration )
    return change * ( pow( clock / duration - 1, 5 ) + 1 ) + initial
end).addEasing("inOutQuint", function( clock, initial, change, duration )
    local clock = clock / duration * 2
    if clock < 1 then
        return change / 2 * pow( clock, 5 ) + initial
    end

    return change / 2 * (pow( clock - 2, 5 ) + 2 ) + initial
end).addEasing("outInQuint", function( clock, initial, change, duration )
    if clock < duration / 2 then
        return easing.outQuint( clock * 2, initial, change / 2, duration )
    end

    return easing.inQuint( ( clock * 2 ) - duration, initial + change / 2, change / 2, duration )
end)

-- Sine easing functions
Tween.addEasing("inSine", function( clock, initial, change, duration )
    return -change * cos( clock / duration * ( pi / 2 ) ) + change + initial
end).addEasing("outSine", function( clock, initial, change, duration )
    return change * sin( clock / duration * ( pi / 2 ) ) + initial
end).addEasing("inOutSine", function( clock, initial, change, duration )
    return -change / 2 * ( cos( pi * clock / duration ) - 1 ) + initial
end).addEasing("outInSine", function( clock, initial, change, duration )
    if clock < duration / 2 then
        return easing.outSine( clock * 2, initial, change / 2, duration )
    end

    return easing.inSine( ( clock * 2 ) - duration, initial + change / 2, change / 2, duration )
end)

-- Expo easing functions
Tween.addEasing("inExpo", function( clock, initial, change, duration )
    if clock == 0 then
        return initial
    end
    return change * pow( 2, 10 * ( clock / duration - 1 ) ) + initial - change * 0.001
end).addEasing("outExpo", function( clock, initial, change, duration )
    if clock == duration then
        return initial + change
    end

    return change * 1.001 * ( -pow( 2, -10 * clock / duration ) + 1 ) + initial
end).addEasing("inOutExpo", function( clock, initial, change, duration )
    if clock == 0 then
        return initial
    elseif clock == duration then
        return initial + change
    end

    local clock = clock / duration * 2
    if clock < 1 then
        return change / 2 * pow( 2, 10 * ( clock - 1 ) ) + initial - change * 0.0005
    end

    return change / 2 * 1.0005 * ( -pow( 2, -10 * ( clock - 1 ) ) + 2 ) + initial
end).addEasing("outInExpo", function( clock, initial, change, duration )
    if clock < duration / 2 then
        return easing.outExpo( clock * 2, initial, change / 2, duration )
    end

    return easing.inExpo( ( clock * 2 ) - duration, initial + change / 2, change / 2, duration )
end)

-- Circ easing functions
Tween.addEasing("inCirc", function( clock, initial, change, duration )
    return -change * ( sqrt( 1 - pow( clock / duration, 2 ) ) - 1 ) + initial
end).addEasing("outCirc", function( clock, initial, change, duration )
    return change * sqrt( 1 - pow( clock / duration - 1, 2 ) ) + initial
end).addEasing("inOutCirc", function( clock, initial, change, duration )
    local clock = clock / duration * 2
    if clock < 1 then
        return -change / 2 * ( sqrt( 1 - clock * clock ) - 1 ) + initial
    end

    clock = clock - 2
    return change / 2 * ( sqrt( 1 - clock * clock ) + 1 ) + initial
end).addEasing("outInCirc", function( clock, initial, change, duration )
    if clock < duration / 2 then
        return easing.outCirc( clock * 2, initial, change / 2, duration )
    end

    return easing.inCirc( ( clock * 2 ) - duration, initial + change / 2, change / 2, duration )
end)

-- Elastic easing functions
local function calculatePAS(p,a,change,duration)
  local p, a = p or duration * 0.3, a or 0
  if a < abs( change ) then
      return p, change, p / 4 -- p, a, s
  end

  return p, a, p / ( 2 * pi ) * asin( change / a ) -- p,a,s
end

Tween.addEasing("inElastic", function( clock, initial, change, duration, amplitude, period )
    if clock == 0 then return initial end

    local clock, s = clock / duration
    if clock == 1 then
        return initial + change
    end

    clock, p, a, s = clock - 1, calculatePAS( p, a, change, duration )
    return -( a * pow( 2, 10 * clock ) * sin( ( clock * duration - s ) * ( 2 * pi ) / p ) ) + initial
end).addEasing("outElastic", function( clock, initial, change, duration, amplitude, period )
    if clock == 0 then
        return initial
    end
    local clock, s = clock / duration

    if clock == 1 then
        return initial + change
    end

    local p,a,s = calculatePAS( period, amplitude, change, duration )
    return a * pow( 2, -10 * clock ) * sin( ( clock * duration - s ) * ( 2 * pi ) / p ) + change + initial
end).addEasing("inOutElastic", function( clock, initial, change, duration, amplitude, period )
    if clock == 0 then return initial end

    local clock = clock / duration * 2
    if clock == 2 then return initial + change end

    local clock, p, a, s = clock - 1, calculatePAS( period, amplitude, change, duration )
    if clock < 0 then
        return -0.5 * ( a * pow( 2, 10 * clock ) * sin( ( clock * duration - s ) * ( 2 * pi ) / p ) ) + initial
    end

    return a * pow( 2, -10 * clock ) * sin( ( clock * duration - s ) * ( 2 * pi ) / p ) * 0.5 + change + initial
end).addEasing("outInElastic", function( clock, initial, change, duration, amplitude, period )
    if clock < duration / 2 then
        return easing.outElastic( clock * 2, initial, change / 2, duration, amplitude, period )
    end

    return easing.inElastic( ( clock * 2 ) - duration, initial + change / 2, change / 2, duration, amplitude, period )
end)

-- Back easing functions
Tween.addEasing("inBack", function( clock, initial, change, duration, s )
    local s, clock = s or 1.70158, clock / duration

    return change * clock * clock * ( ( s + 1 ) * clock - s ) + initial
end).addEasing("outBack", function( clock, initial, change, duration, s )
    local s, clock = s or 1.70158, clock / duration - 1

    return change * ( clock * clock * ( ( s + 1 ) * clock + s ) + 1 ) + initial
end).addEasing("inOutBack", function( clock, initial, change, duration, s )
    local s, clock = ( s or 1.70158 ) * 1.525, clock / duration * 2
    if clock < 1 then
        return change / 2 * ( clock * clock * ( ( s + 1 ) * clock - s ) ) + initial
    end

    clock = clock - 2
    return change / 2 * ( clock * clock * ( ( s + 1 ) * clock + s ) + 2 ) + initial
end).addEasing("outInBack", function( clock, initial, change, duration, s )
    if clock < duration / 2 then
        return easing.outBack( clock * 2, initial, change / 2, duration, s )
    end

    return easing.inBack( ( clock * 2 ) - duration, initial + change / 2, change / 2, duration, s )
end)

-- Bounce easing functions
Tween.addEasing("inBounce", function( clock, initial, change, duration )
    return change - easing.outBounce( duration - clock, 0, change, duration ) + initial
end).addEasing("outBounce", function( clock, initial, change, duration )
    local clock = clock / duration
    if clock < 1 / 2.75 then
        return change * ( 7.5625 * clock * clock ) + initial
    elseif clock < 2 / 2.75 then
        clock = clock - ( 1.5 / 2.75 )
        return change * ( 7.5625 * clock * clock + 0.75 ) + initial
    elseif clock < 2.5 / 2.75 then
        clock = clock - ( 2.25 / 2.75 )
        return change * ( 7.5625 * clock * clock + 0.9375 ) + initial
    end

    clock = clock - (2.625 / 2.75)
    return change * (7.5625 * clock * clock + 0.984375) + initial
end).addEasing("inOutBounce", function( clock, initial, change, duration )
    if clock < duration / 2 then
        return easing.inBounce( clock * 2, 0, change, duration ) * 0.5 + initial
    end

    return easing.outBounce( clock * 2 - duration, 0, change, duration ) * 0.5 + change * .5 + initial
end).addEasing("outInBounce", function( clock, initial, change, duration )
    if clock < duration / 2 then
        return easing.outBounce( clock * 2, initial, change / 2, duration )
    end

    return easing.inBounce( ( clock * 2 ) - duration, initial + change / 2, change / 2, duration )
end)
