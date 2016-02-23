--[[
    Titanium make file

    Retrieves all source files and compiles them into one.
]]

local ignore = {
    [".DS_Store"] = true;
    ["loadFirst.cfg"] = true;
}

local function getContents( dir, _results )
    local results = _results or {}

    local filePath
    for _, file in ipairs( fs.list( dir ) ) do
        filePath = fs.combine( dir, file )

        if not ignore[ file ] then
            if fs.isDir( filePath ) then
                getContents( filePath, results )
            else
                results[ #results + 1 ] = filePath
            end
        end
    end

    return results
end

local files, exports = getContents( "src" ), {}
local scripts, scriptFiles = getContents( "src/scripts" ), {}
local preLoadFiles = {}

if fs.exists( "src/loadFirst.cfg" ) then
    local h = fs.open( "src/loadFirst.cfg", "r" )
    local content = h.readAll()
    h.close()

    if content then
        for name in content:gmatch( "[^\n]+" ) do preLoadFiles[ #preLoadFiles + 1 ] = name end
    end
end

local h, file
for i = 1, #files do
    file = files[ i ]

    h = fs.open( file, "r" )
    exports[ fs.getName( file ) ] = h.readAll()
    h.close()
end

for i = 1, #scripts do scriptFiles[ fs.getName( scripts[ i ] ) ] = true end


local fileHandle = fs.open("build/titanium.lua", "w")
fileHandle.write([[local files = ]] .. textutils.serialise( exports ) .. [[

local scriptFiles = ]] .. textutils.serialise( scriptFiles ) .. [[

local preLoad = ]] .. textutils.serialise( preLoadFiles ) .. [[

local loaded = {}
local function loadFile( name, verify )
    if loaded[ name ] then return end

    local content = files[ name ]
    if content then
        local output, err = loadstring( content, name )
        if not output or err then return error( "Failed to load Lua chunk. File '"..name.."' has a syntax error: "..tostring( err ) ) end

        local ok, err = pcall( output )
        if not ok or err then return error( "Failed to execute Lua chunk. File '"..name.."' crashed: "..tostring( err ) ) end

        if verify then
            local className = name:gsub( "%..*", "" )
            local class = classLib.getClass( className )

            if class then
                if not class:isCompiled() then class:compile() end
            else return error( "File '"..name.."' failed to create class '"..className.."'" ) end
        end

        loaded[ name ] = true
    else return error("Failed to load Titanium. File '"..tostring( name ).."' cannot be found.") end
end

-- Load our class file
loadFile( "Class.lua" )

-- Load any files specified by our config file
for i = 1, #preLoad do loadFile( preLoad[ i ] ) end

-- Load all other files
for name, _ in pairs( files ) do loadFile( name, true ) end
]])

fileHandle.close()
