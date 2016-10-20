--[[
    The main method of packaging custom projects that use Titanium.

    Call with --help/-h to display help
]]

local lfs, explore, addFromExplore, showHelp = type( fs ) ~= "table" and require "lfs"

--[[ Constants ]]--
local SETTINGS, FLAGS = {
    EXTRACT = {
        TARGETS = {},
        EXCLUDE = {},
        ALLOW_OVERRIDE = true
    },
    TITANIUM = {
        INSTALL = false,
        DISABLE_CHECK = false
    },
    SOURCE = {
        CLASSES = {},
        EXCLUDE = {},
        LOCATION = "src"
    },
    VFS = {
        ENABLE = true,
        RESTRICT = false,
        EXCLUDE = {}
    },

    GLOBAL_EXCLUDE = {
        [".DS_Store"] = true
    },

    PICKLE_LOCATION = "Pickle.lua",

    MINIFY_LOCATION = "Minify.lua",
    MINIFY_SOURCE = false,

    INIT_FILE = false,

    OUTPUT_LOCATION = "titanium-project.tpkg"
}

FLAGS = {
    -- Source flags
    {"source", "s", function( path ) SETTINGS.SOURCE.LOCATION = path end, true, "Defines the source folder for your project. Files not set as a class file or extractable (see below) will be accessible via virtual file system"},
    {"class-source", "cs", function( path ) addFromExplore( path, SETTINGS.SOURCE.CLASSES ) end, true, "Files inside the path given will be set as a class file and will be executed and the class created will be compiled"},
    {"extract", "e", function( path ) addFromExplore( path, SETTINGS.EXTRACT.TARGETS ) end, true, "Files inside the path given will be extracted from the package when it's executed"},
    {"output", "o", function( location ) SETTINGS.OUTPUT_LOCATION = location end, true, "The output path of the package"},
    {"init", "i", function( path ) SETTINGS.INIT_FILE = path end, true, "This file will be run when the package is executed"},
    {"minify", "m", function() SETTINGS.MINIFY_SOURCE = true end, false, "Files ending with the `.ti` or `.lua` extension will be minified"},

    -- Path Exclusion
    {"exclude-class-source", "exclude-cs", function( path ) addFromExplore( path, SETTINGS.SOURCE.EXCLUDE ) end, true, "Files inside this path will not be loaded as a class file"},
    {"exclude-extract", false, function( path ) addFromExplore( path, SETTINGS.EXTRACT.EXCLUDE ) end, true, "Files inside this path will not be extracted"},
    {"exclude-vfs", false, function( path ) addFromExplore( path, SETTINGS.VFS.EXCLUDE ) end, true, "Files inside this path will not be available via the virtual file system"},
    {"exclude", false, function( path ) addFromExplore( path, SETTINGS.GLOBAL_EXCLUDE ) end, true, "Files inside this path will not be processed"},
    {"block-extract-override", false, function() SETTINGS.EXTRACT.ALLOW_OVERRIDE = false end, false, "Disallows the package to be extracted to a certain path at execution time"},

    -- Titanium flags
    {"titanium", "ti", function( path ) SETTINGS.TITANIUM.INSTALL = path end, true, "Automatically download titanium to the path specified and load it if Titanium isn't already loaded"},
    {"titanium-disable-check", "tid", function() SETTINGS.TITANIUM.DISABLE_CHECK = true end, false, "Supresses the error that will occur when packaging class files without -ti. Allows Titanium to be loaded externally"},

    -- VFS Flags
    {"vfs-disable", false, function() SETTINGS.VFS.ENABLE = false end, false, "Disables the virtual file system"},
    {"vfs-restrict", false, function() SETTINGS.VFS.RESTRICT = true end, false, "The packages environment _G and _ENV variables will refer to the sandbox environment"},

    -- Advanced flags
    {"pickle-source", false, function( path ) SETTINGS.PICKLE_LOCATION = path end, true, "The path given will be executed when the builder is run outside of ComputerCraft and will be used to serialize tables"},
    {"minify-source", false, function( path ) SETTINGS.MINIFY_LOCATION = path end, true, "The path given will be executed when the builder is run with minify enabled. This file will be used to minify Lua source code"},

    -- Help flag
    {"help", "h", function()
        print( "Titanium packager help\n" .. ("="):rep( 22 ) .. "\n" )
        local isCC = type( textutils ) == "table" and type( term ) == "table"
        local isColour = isCC and term.isColour and ( type( term.isColour ) ~= "function" or ( type( term.isColour ) == "function" and term.isColour() ) )

        local function colPrint( col, text ) term.setTextColour( col ); write( text ) end

        showHelp = true
        for i = 1, #FLAGS do
            local f = FLAGS[ i ]

            if isColour then
                colPrint( colours.orange, ("--%s"):format( f[ 1 ] ) )
                if f[ 2 ] then colPrint( colours.blue, "(-"..f[ 2 ]..")" ) end
                colPrint( colours.white, ": " .. f[ 5 ] .. "\n\n" )
            else
                print( ("--%s%s: %s"):format( f[ 1 ], f[ 2 ] and "(-"..f[ 2 ]..")" or "", f[ 5 ] ) .. "\n" )
            end

            if isCC then
                local x, y = term.getCursorPos()

                term.setCursorPos( 1, select( 2, term.getSize() ) )
                term.write "Any key to continue (q to exit)"
                while true do
                    if select( 2, os.pullEvent "key" ) == keys.q then sleep() return end
                    break
                end

                term.clearLine()
                term.setCursorPos( x, y )
            end
        end
    end, false, "Show this help menu"}
}

--[[ Helper Functions ]]--
local function isDir( path )
    if type( fs ) == "table" then
        return fs.isDir( path )
    else
        local attr, err = lfs.attributes( path, "mode" )
        if not attr and err then
            error("Failed to fetch attributes of path '"..tostring( path ).."': "..tostring( err ))
        end

        return attr == "directory"
    end
end

local function isFile( path )
    if type( fs ) == "table" then
        return fs.exists( path ) and not fs.isDir( path )
    else
        local attr, err = lfs.attributes( path, "mode" )
        if not attr and err then
            error("Failed to fetch attributes of path '"..tostring( path ).."': "..tostring( err ))
        end

        return attr == "file"
    end
end

function explore( path, results )
    local results = results or {}

    if isDir( path ) then
        if type( fs ) == "table" then
            for _, file in pairs( fs.list( path ) ) do
                local p = path .. "/" .. file
                if isDir( p ) then
                    results = explore( p, results )
                else
                    results[ #results + 1 ] = p
                end
            end
        else
            for file in lfs.dir( path ) do
                if file ~= "." and file ~= ".." then
                    local p = path .. "/" .. file

                    if lfs.attributes( p, "mode" ) == "directory" then
                        results = explore( p, results )
                    elseif lfs.attributes( p, "mode" ) == "file" then
                        results[ #results + 1 ] = p
                    end
                end
            end
        end
    elseif isFile( path ) then results[ #results + 1 ] = path
    else return error("Path '"..tostring( path ).."' cannot be explored. Doesn't exist.") end

    return results
end

function addFromExplore( path, tbl )
    local r = explore( path )
    for i = 1, #r do tbl[ r[ i ] ] = true end
end

local preprocessTargets = {"class", "extends", "alias", "mixin"}
local function preprocess( text )
    local keyword
    for i = 1, #preprocessTargets do
        keyword = preprocessTargets[ i ]

        for value in text:gmatch( keyword .. " ([_%a][_%w]*)%s" ) do
            text = text:gsub( keyword .. " " .. value, keyword.." \""..value.."\"" )
        end
    end

    for name in text:gmatch( "abstract class (\".[^%s]+\")" ) do
        text = text:gsub( "abstract class "..name, "class "..name.." abstract()" )
    end

    return text
end

local function getFileContents( path, allowMinify, allowPreprocess )
    if isFile( path ) then
        local file, err = io.open( path )
        if not file or err then
            return error("Failed to fetch file contents of '"..path.."': "..tostring( err ))
        end

        local cnt = file:read("*a")
        file:close()

        cnt = allowPreprocess and preprocess( cnt ) or cnt
        if allowMinify and SETTINGS.MINIFY_SOURCE then
            if type( _G.Minify ) ~= "function" then dofile( SETTINGS.MINIFY_LOCATION ) end

            local ok, cnt = Minify( cnt )
            if not ok and cnt then error( "Failed to minify target '"..tostring( path ).."': "..tostring( cnt ) ) end

            return cnt
        end

        return cnt
    else
        return error("Cannot get file contents of path '"..tostring( path ).."'. Is directory.")
    end
end

local function serialise( target )
    if type( textutils ) == "table" then
        return textutils.serialise( target )
    else
        return pickle( target )
    end
end

local function getName( path )
    if fs and fs.getName then
        return fs.getName( path )
    end

    return path:match ".-([^/\\]-[^%.]+)$"
end

--[[ Settings Initialisation ]]--

local function checkFlags( property, double, singleton, value )
    for f = 1, #FLAGS do
        flag = FLAGS[ f ]
        if ( ( singleton and not flag[ 4 ] ) or ( not singleton and flag[ 4 ] ) ) and ( ( double and flag[ 1 ] == property ) or ( not double and flag[ 2 ] == property ) ) then
            flag[ 3 ]( value )
            return true
        end
    end
end

local args = { ... }
for i = 1, #args do
    local double, property, value = args[ i ]:match "^(%-?%-)([%w%-]+)%=(.+)" --Format: -(-)property(-)name=value
    if double and property and value then
        if not checkFlags( property, double == "--", false, value ) then
            error("Argument invalid. Argument accepting flag for type '"..args[ i ].."' not found.")
        end
    else
        local double, property = args[ i ]:match "^(%-?%-)([%w%-]+)$"
        if double and property then
            if not checkFlags( property, double == "--", true, value ) then
                error("Argument invalid. Argument rejecting flag for type '"..args[ i ].."' not found.")
            end
        else
            error("Argument format invalid ("..tostring( args[ i ] ).."). Should be format '-(-)property=value'")
        end
    end
end

if showHelp then return end

--[[ Main ]]--
local GLOBAL_EXCLUDE, EXTRACT_EXCLUDE, CLASS_EXCLUDE, VFS_EXCLUDE = SETTINGS.GLOBAL_EXCLUDE, SETTINGS.EXTRACT.EXCLUDE, SETTINGS.SOURCE.EXCLUDE, SETTINGS.VFS.EXCLUDE
local vfs_assets, extract_assets, class_assets = {}, {}, {}
for file in pairs( SETTINGS.EXTRACT.TARGETS ) do
    if not ( GLOBAL_EXCLUDE[ file ] or EXTRACT_EXCLUDE[ file ] ) then
        extract_assets[ file ] = getFileContents( file, file:find("%.lua$") or file:find("%.ti$") )
    end
end

for file in pairs( SETTINGS.SOURCE.CLASSES ) do
    if not ( GLOBAL_EXCLUDE[ file ] or CLASS_EXCLUDE[ file ] ) then
        class_assets[ getName( file ) ] = getFileContents( file, true, true )
    end
end

do
    local r, rI = explore( SETTINGS.SOURCE.LOCATION )
    for i = 1, #r do
        rI = r[ i ]
        if not ( class_assets[ getName( rI ) ] or extract_assets[ rI ] ) and not ( GLOBAL_EXCLUDE[ rI ] or VFS_EXCLUDE[ rI ] ) then
            vfs_assets[ rI ] = getFileContents( rI, rI:find("%.lua$") or rI:find("%.ti$") )
        end
    end
end

if type( textutils ) ~= "table" then
    dofile( SETTINGS.PICKLE_LOCATION )
end

--[[ Output ]]--
local output = [=[
--[[
    Built using Titanium Packager (Harry Felton - hbomb79)
]]

local exportDirectory = ]=] .. ( SETTINGS.EXTRACT.ALLOW_OVERRIDE and 'select( 1, ... ) or ""' or '""' ) .. "\n"

if next( class_assets ) then
    if not SETTINGS.TITANIUM.DISABLE_CHECK and not SETTINGS.TITANIUM.INSTALL then
        error "Failed to compile project. When class source is present, The Titanium module must be set to automatically install. Use flag --titanium to set the install path, or --titanium-disable-check to disable this check"
    end

    output = output .. "local classSource = " .. serialise( class_assets ).."\n"
end

local useVFS = SETTINGS.VFS.ENABLE and next( vfs_assets )
if useVFS then
    output = output .. "local vfsAssets = " .. serialise( vfs_assets ) .. [[

local VFS_ENV = setmetatable({
    fs = setmetatable({}, { __index = _G["fs"] })
},{__index = _ENV or getfenv()})
]] .. ( SETTINGS.VFS.RESTRICT and "VFS_ENV._G = VFS_ENV\nVFS_ENV._ENV = VFS_ENV\n" or "" ) .. [[

function VFS_ENV.load(src, name, mode, env)
	return load( src, name or '(load)', mode, env or VFS_ENV )
end

function VFS_ENV.loadstring(src, name)
	return VFS_ENV.load( src, name, 't', VFS_ENV )
end

function VFS_ENV.loadfile(file, env)
	local _ENV = VFS_ENV
	local h = fs.open( file, "r" )
	if h then
		local fn, e = load(h.readAll(), fs.getName(file), 't', env or VFS_ENV)
		h.close()
		return fn, e
	end

	return nil, 'File not found'
end
if type( setfenv ) == "function" then setfenv( VFS_ENV.loadfile, VFS_ENV ) end

function VFS_ENV.dofile(file)
	local _ENV = VFS_ENV
	local fn, e = loadfile(file, VFS_ENV)

	if fn then return fn()
	else error(e, 2) end
end
if type( setfenv ) == "function" then setfenv( VFS_ENV.dofile, VFS_ENV ) end

local VFS = VFS_ENV.fs
function VFS.open( path, mode )
    if vfsAssets[ path ] then
        if mode == "w" or mode == "wb" or mode == "a" or mode == "ab" then
            return error("Cannot open file in mode '"..tostring( mode ).."'. File is inside of Titanium VFS and is read only")
        end

        local content, handle = vfsAssets[ path ], {}
        if mode == "rb" then
            handle.read = function()
                if #content == 0 then return end
                local b = content:sub( 1, 1 ):byte()

                content = content:sub( 2 )
                return b
            end
        end

        handle.readLine = function()
            if #content == 0 then return end

            local line, rest = content:match "^([^\n\r]*)[\n\r](.*)$"

            content = rest or ""
            return line or content
        end

        handle.readAll = function()
            if #content == 0 then return end

            local c = content
            content = ""

            return c
        end

        handle.close = function() content = "" end

        return handle
    else return fs.open( fs.combine( exportDirectory, path ), mode ) end
end

function VFS.exists( path )
    if vfsAssets[ path ] then
        return true
    end

    return fs.exists( fs.combine( exportDirectory, path ) )
end
]]
end

if next( extract_assets ) then
    output = output .. "local extractAssets = "..serialise( extract_assets ) .. [[

for file, content in pairs( extractAssets ) do
    local path = fs.combine( exportDirectory, file )
    if not fs.exists( path ) then
        local h = fs.open( path, "w" )
        h.write( content )
        h.close()
    end
end
]]
end

local titanium = SETTINGS.TITANIUM.INSTALL
if titanium then
    output = output .. [[
local tiPath = fs.combine( exportDirectory, "]] .. titanium .. [[")
if not fs.exists( tiPath ) then
    local h = http.get "https://gist.githubusercontent.com/hbomb79/28de5f20b2053ed42cec855c778910d1/raw/titanium.min.lua"
    if h then
        local f = fs.open( tiPath, "w" )
        f.write( h.readAll() )
        f.close()

        h.close()
    else error "Failed to download Titanium" end
end

if not _G.Titanium then dofile( tiPath ) end
]]
end

output = output .. [[
if not _G.Titanium then
    return error "Failed to execute Titanium package. Titanium is not loaded. Please load Titanium before executing this package, or repackage this application using the --titanium flag."
end
]]

if next( class_assets ) then
    output = output .. [[

local loaded = {}
local function loadClass( name, source )
    if loaded[ name ] then return end

    local className = name:gsub( "%..*", "" )
    if not Titanium.getClass( className ) then
        local output, err = ( VFS_ENV or _G ).loadstring( source, name )
        if not output or err then return error( "Failed to load Lua chunk. File '"..name.."' has a syntax error: "..tostring( err ), 0 ) end

        local ok, err = pcall( output )
        if not ok or err then return error( "Failed to execute Lua chunk. File '"..name.."' crashed: "..tostring( err ), 0 ) end

        local class = Titanium.getClass( className )
        if class then
            if not class:isCompiled() then class:compile() end
            print( name )
            loaded[ name ] = true
        else return error( "File '"..name.."' failed to create class '"..className.."'" ) end
    else
        print( "WARNING: Class " .. className .. " failed to load because a class with the same name already exists." )
    end
end

Titanium.setClassLoader(function( c )
    local name = classSource[ c .. ".lua" ] and c .. ".lua" or c .. ".ti"
    loadClass( name, classSource[ name ] )
end)
for name, source in pairs( classSource ) do
    loadClass( name, source )
end
]]
end

local init = SETTINGS.INIT_FILE
if init then
    output = output .. ( useVFS and "\nTitanium.VFS = VFS_ENV\n" or "\nTitanium.VFS = nil\n" )

    if useVFS and vfs_assets[ init ] then
        output = output .. [[

local fn, err = VFS_ENV.loadfile "]]..init..[["
if fn then fn()
else return error( "Failed to run file from bundle vfs: "..tostring( err ) ) end
]]
    elseif extract_assets[ init ] then
        if useVFS then
            output = output .. "VFS_ENV.dofile '"..init.."'\n"
        else
            output = output .. "dofile( fs.combine( exportDirectory, '"..init.."' ) )"
        end
    else
        error("Init file '"..init.."' is invalid. Not found inside application bundle. " .. ( not SETTINGS.VFS.ENABLE and not next( extract_assets ) and "This maybe caused by the VFS and extract being disabled. Re-enable the VFS or extract the files needed using --extract" or "" ))
    end

    if useVFS then
        output = output .. "\nTitanium.VFS = nil\n"
    end
else
    error("Failed to compile project. No init file specified (--init/-i)=path")
end

local handle = io.open( SETTINGS.OUTPUT_LOCATION, "w" )
if SETTINGS.MINIFY_SOURCE then
    local ok, cnt = Minify( output )
    if not ok and cnt then error( "Failed to minify complete build file: " .. cnt ) end

    handle:write( cnt )
else handle:write( output ) end

handle:close()
