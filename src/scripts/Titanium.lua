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
    need not be acounted for, Titanium will automatically fill those as 'blank' pixels by setting them as 'transparent'.

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

local abs, pow, asin, sin, sqrt, pi = math.abs, math.pow, math.asin, math.sin, math.sqrt, math.pi
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
