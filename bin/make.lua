--[[
    Titanium build script - Basic

    Compatible with ComputerCraft
]]

local args = { ... }
local location = args[ 1 ] or ""

local ignore = {
    [".DS_Store"] = true;
    ["loadFirst.cfg"] = true;
}

local function getContents( dir, _results )
    local results = _results or {}

    local filePath
    for _, file in ipairs( fs.list( dir ) ) do
        filePath = fs.combine( dir, file )

        if not ignore[ file ] and not string.find( filePath, ".*%.swp" ) and not string.find( filePath, ".*%.swo" ) then -- doesn't add files that are set to be ignored or .swp files (generated by Vim).
            if fs.isDir( filePath ) then
                getContents( filePath, results )
            else
                print( "Found: " .. filePath )
                results[ #results + 1 ] = filePath
            end
        end
    end

    return results
end
print( "Building Titanium\nSearching source directory" )
local files, exports = getContents( fs.combine( location, "src" ) ), {}
print( "Searching src/scripts directory" )
local scripts, scriptFiles = getContents( fs.combine( location, "src/scripts" ) ), {}
local preLoadFiles = {}

if fs.exists( "src/loadFirst.cfg" ) then
    local h = io.open( "src/loadFirst.cfg", "r" )

    for name in h:lines() do
        preLoadFiles[ #preLoadFiles + 1 ] = name
        print( "Assigning file '"..name.."' as preload" )
    end

    h:close()
end

local h, file
for i = 1, #files do
    file = files[ i ]

    h = fs.open( file, "r" )
    exports[ fs.getName( file ) ] = h.readAll()
    h.close()

    print( "File '"..file.."' read." )
end

for i = 1, #scripts do scriptFiles[ fs.getName( scripts[ i ] ) ] = true; print( "Assigning file '"..scripts[ i ].."' as script" ) end


local fileHandle = fs.open("build/titanium.lua", "w")
fileHandle.write([[local files = ]] .. textutils.serialise( exports ) .. [[

local scriptFiles = ]] .. textutils.serialise( scriptFiles ) .. [[

local preLoad = ]] .. textutils.serialise( preLoadFiles ) .. [[

local loaded = {}
local function loadFile( name, verify )
    if loaded[ name ] then return end

    local content = files[ name ]
    if content then
        local output, err = loadstring( Titanium and not scriptFiles[ name ] and Titanium.preprocess( content ) or content, name )
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
for name in pairs( files ) do
    if not scriptFiles[ name ] then
        loadFile( name, true )
    end
end

-- Load all script files
for name in pairs( scriptFiles ) do
    loadFile( name, false )
end
]])

fileHandle.close()
