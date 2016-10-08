--[[
    Titanium Builder - Advanced

    This builder is not compatible with ComputerCraft.
]]

-- Settings
local SOURCE_FOLDER, OUTPUT_PATH, MINIFY_SOURCE, QUIET
local flags = {
    {"source", "s", function( target ) SOURCE_FOLDER = target; print("Source directory set to: "..target) end, 1},
    {"output", "o", function( output ) OUTPUT_PATH = output; print("Output path set to: "..output) end, 1},
    {"minify", "m", function() MINIFY_SOURCE = true; print("Minification enabled") end, 0},
    {"quiet", "q", function() QUIET = true end, 0},
    {"help", "h", function()
        print([[
Titanium Constructor - Help

The constructor allows Titaniums source code to be compiled into one executable file.
Upon execution all Titanium classes will be loaded and compiled.

Flags can be used to alter the building of the source:

--source (-s) <directory>: Specifies the directory where the Titanium source is stored.
--output (-o) <path>: Specifies the location that the build file should be saved. Any current file will be overwritten.
--tag (-t) <tag>: The argument following will be added into the build comment as the build version. Eg: 0.1-alpha.
--minify (-m): All source files inside that are NOT .cfg files will be minified.
--quiet (-q): The amount of information printed to the screen is reduced dramatically.
--help (-h): Shows this help screen.
        ]])

        print("Help menu opened")
        os.exit()
    end, 0}
}
local ignore = {".", "..", "loadFirst.cfg", ".DS_Store"}
local oPrint = _G.print

-- Imports
local lfs = require "lfs"
dofile("bin/Pickle.lua")
dofile("bin/Minify.lua")

-- Local functions
local function print( ... )
    if QUIET then return end
    local args = { ... }

    oPrint( table.concat( args, " " ) )
end

local function isInTable( tbl, content )
    for i = 1, #tbl do
        if tbl[ i ] == content then return true end
    end

    return false
end

local function scan( path, files )
    local files = files or {}

    local filePath

    print("Scaning directory '"..path.."'")
    for file in lfs.dir( path ) do
        if not isInTable( ignore, file ) and not string.find( file, ".*%.swp" ) and not string.find( file, ".*%.swo" ) then
            filePath = path .. "/" .. file

            local attrs = lfs.attributes( filePath )

            if attrs.mode == "directory" then
                files = scan( filePath, files )
            else
                table.insert( files, filePath )
                print("Found file '"..filePath.."'")
            end
        end
    end

    return files
end

local function getFileName( path )
    local _, stop = string.find( path, ".*/" )

    return string.sub( path, stop + 1 )
end

local preprocessTargets = {"class", "extends", "alias", "mixin"}
local function preprocess( text )
    local keyword
    for i = 1, #preprocessTargets do
        keyword = preprocessTargets[ i ]

        for value in text:gmatch( keyword .. " (.[^%s]+)" ) do
            if not ( value:find("\"") or value:find("\'") ) then
                text = text:gsub( keyword .. " " .. value, keyword.." \""..value.."\"" )
            end
        end
    end

    for name in text:gmatch( "abstract class (\".[^%s]+\")" ) do
        text = text:gsub( "abstract class "..name, "class "..name.." abstract()" )
    end

    return text
end


-- Search flags
local args, arg, i = { ... }, false, 1
while i <= #args do
    arg = args[ i ]
    local foundFlag

    local flag
    for i = 1, #flags do
        flag = flags[ i ]

        if ( flag[ 1 ] and "--" .. flag[ 1 ] == arg ) or ( flag[ 2 ] and "-" .. flag[ 2 ] == arg ) then
            foundFlag = flag
            break
        end
    end

    if foundFlag then
        -- Process its arguments
        if foundFlag[ 4 ] and not args[ i + foundFlag[ 4 ] ] then
            return error("Flag '"..arg.."' requires "..foundFlag[ 4 ].." arguments.")
        end

        local arguments = {}
        for k = i + 1, i + foundFlag[4] do
            table.insert( arguments, args[ k ] )
            i = i + 1
        end

        foundFlag[3]( unpack( arguments ) )
    else
        return error( "Unknown flag specified: "..tostring( arg ) )
    end

    i = i + 1
end

if not SOURCE_FOLDER then error( "Source directory not set, use --source (-s) <source_directory>. Use --help to show help." ) end
if not OUTPUT_PATH then error( "Output path not set, use --output (-o) <output_path>. Use --help to show help." ) end

-- Scan for files
print("Scanning for files in source and scripts directories")
local rawFiles, rawScriptFiles = scan( SOURCE_FOLDER ), scan( SOURCE_FOLDER .. "/scripts" )

-- Compile files
local scriptFiles = {}
for i = 1, #rawScriptFiles do
    scriptFiles[ getFileName( rawScriptFiles[ i ] ) ] = true
end

local exportFiles = {}
for i = 1, #rawFiles do
    local h = io.open( rawFiles[ i ], "r" )
    local content = h:read("*all")
    h:close()

    local name = getFileName( rawFiles[ i ] )

    if not ( scriptFiles[ name ] ) then
        content = preprocess( content )
    end

    if MINIFY_SOURCE then
        local ok, mContent = Minify( content )

        if not ok then return error( "Failed to minify content '"..rawFiles[i]..": "..tostring( content ) ) end
        print("Minified file '"..name.."'")

        content = mContent
    end

    exportFiles[ name ] = content
end

local preLoad = {}
local handle = io.open( SOURCE_FOLDER .. "/loadFirst.cfg", "r" )
if handle then
    for line in handle:lines() do
        table.insert( preLoad, line )
    end
end

-- Generate output
local footer = [[local files = ]] .. tostring( pickle( exportFiles ) ) .. [[

local scriptFiles = ]] .. tostring( pickle( scriptFiles ) ) .. [[

local preLoad = ]] .. tostring( pickle( preLoad ) ) .. [[

local loaded = {}
local function loadFile( name, verify )
    if loaded[ name ] then return end

    local content = files[ name ]
    if content then
        local output, err = loadstring( content, name )
        if not output or err then return error( "Failed to load Lua chunk. File '"..name.."' has a syntax error: "..tostring( err ), 0 ) end

        local ok, err = pcall( output )
        if not ok or err then return error( "Failed to execute Lua chunk. File '"..name.."' crashed: "..tostring( err ), 0 ) end

        if verify then
            local className = name:gsub( "%..*", "" )
            local class = Titanium.getClass( className )

            if class then
                if not class:isCompiled() then class:compile() end
            else return error( "File '"..name.."' failed to create class '"..className.."'" ) end
        end

        loaded[ name ] = true
    else return error("Failed to load Titanium. File '"..tostring( name ).."' cannot be found.") end
end

-- Load our class file
loadFile( "Class.lua" )

Titanium.setClassLoader(function( name )
    local fName = name..".ti"

    if not files[ fName ] then
        return error("Failed to find file '"..fName..", to load missing class '"..name.."'.", 3)
    else
        loadFile( fName, true )
    end
end)

-- Load any files specified by our config file
for i = 1, #preLoad do loadFile( preLoad[ i ], not scriptFiles[ preLoad[ i ] ] ) end

-- Load all class files
for name in pairs( files ) do if not scriptFiles[ name ] then
    loadFile( name, true )
end end

-- Load all script files
for name in pairs( scriptFiles ) do loadFile( name, false ) end
]]

local h = io.open( OUTPUT_PATH, "w" )
h:write( footer )
h:close()

print("Complete")
_G.print = oPrint -- restore old print
