--[[
    The main method of packaging custom projects that use Titanium.

    Call with --help/-h to display help
]]

local lfs, explore, showHelp = type( fs ) ~= "table" and require "lfs"

--[[ Constants ]]--
local SETTINGS = {
    EXTRACT = {
        targets = {},
        output = "/"
    },
    TITANIUM = {
        INSTALL = false,
        AUTOLOAD = false,
        DISABLE_CHECK = false
    },
    SOURCE = {
        classes = {},
        location = "src"
    },

    PICKLE_LOCATION = "Pickle.lua",

    MINIFY_LOCATION = "Minify.lua",
    MINIFY_SOURCE = false,

    INIT_FILE = false,

    OUTPUT_LOCATION = "titanium-project.tpkg"
}

local FLAGS = {
    {"source", "s", function( path )
        SETTINGS.SOURCE.location = path
    end, true},

    {"class-source", "cs", function( path )
        local r = explore( path )
        for i = 1, #r do SETTINGS.SOURCE.classes[ r[ i ] ] = true end
    end, true},

    {"extract", "e", function( path )
        local r = explore( path )
        for i = 1, #r do SETTINGS.EXTRACT.targets[ r[ i ] ] = true end
    end, true},

    {"output", "o", function( location ) SETTINGS.OUTPUT_LOCATION = location end, true},

    {"pickle-source", false, function( path )
        SETTINGS.PICKLE_LOCATION = path
    end, true},

    {"minify-source", false, function( path )
        SETTINGS.MINIFY_LOCATION = path
    end, true},

    {"minify", "m", function()
        SETTINGS.MINIFY_SOURCE = true
    end},

    {"titanium", "ti", function( path )
        SETTINGS.TITANIUM.INSTALL = path
    end, true},

    {"titanium-autoload", "tia", function()
        SETTINGS.TITANIUM.AUTOLOAD = true
    end},

    {"titanium-disable-check", "tid", function()
        SETTINGS.TITANIUM.DISABLE_CHECK = true
    end},

    {"init", "i", function( path )
        SETTINGS.INIT_FILE = path
    end, true},

    {"help", "h", function()
        local isCC = type( textutils ) == "table" and type( textutils.pagedPrint ) == "function"
        if isCC then term.setCursorPos( 1, 2 ) term.clear() end

        ( isCC and textutils.pagedPrint or print ) [[
Titanium Packager Help
======================

--source (-s): Defines the source folder for your project. All files inside will be included in the bundle. Files not set as a class file or extractable (see below) will be accessible via virtual file system.
--extract (-e): Files inside the path given will be set as extractable and will be extracted from the bundle when it's executed.
--class-source (-cs): Files inside the path given will be set as a class file and will be executed and the class created will be compiled.
--output (-o): The path given defines where the build file will be output.
--minify (-m): Files ending with the `.ti` or `.lua` extension will be minified.
--titanium (-ti): Inserts a snippet into the build to automatically download titanium to the path specified if it doesn't exist.
--init (-i): Sets the project init file to the path given. This file will be run when the bundle is invoked.
--help (-h): Shows this help menu.

Advanced flags:
---------------
--pickle-source: The path given will be executed when the builder is run outside of ComputerCraft and will be used to serialize tables.
--minify-source: The path given will be executed when the builder is run with minify enabled. This file will be used to minify Lua source code.
]]

    showHelp = true
    end}
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
                if file ~= ".DS_Store" then
                    local p = path .. "/" .. file
                    if isDir( p ) then
                        results = explore( p, results )
                    else
                        results[ #results + 1 ] = p
                    end
                end
            end
        else
            for file in lfs.dir( path ) do
                if file ~= "." and file ~= ".." and file ~= ".DS_Store" then
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

            if not ok and cnt then error( "Failed to minify target '"..tostring(path).."': "..tostring( cnt ) ) end

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
local vfs_assets, extract_assets, class_assets = {}, {}, {}
for file in pairs( SETTINGS.EXTRACT.targets ) do
    extract_assets[ file ] = getFileContents( file, file:find("%.lua$") or file:find("%.ti$") )
end

for file in pairs( SETTINGS.SOURCE.classes ) do
    class_assets[ getName( file ) ] = getFileContents( file, true, true )
end

do
    local r, rI = explore( SETTINGS.SOURCE.location )
    for i = 1, #r do
        rI = r[ i ]
        if not ( class_assets[ rI ] or extract_assets[ rI ] ) then
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

]=]
if next( class_assets ) then
    if not ( SETTINGS.TITANIUM.INSTALL and SETTINGS.TITANIUM.AUTOLOAD and SETTINGS.TITANIUM.DISABLE_CHECK ) then
        error "Failed to compile project. When class source is present, The Titanium module must be set to automatically install AND load. Use flags -ti and -tia to enable, or -tid to disable this check"
    end

    output = output .. "local classSource = " .. serialise( class_assets ).."\n"
end

if next( vfs_assets ) then
    output = output .. "local vfsAssets = " .. serialise( vfs_assets ) .. [[

local VFS_ENV = setmetatable({
    fs = setmetatable({}, { __index = _G["fs"] })
},{__index = _ENV or getfenv()})
VFS_ENV._G = VFS_ENV
VFS_ENV._ENV = VFS_ENV

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
    else return fs.open( path, mode ) end
end

function VFS.exists( path )
    if vfsAssets[ path ] then
        return true
    end

    return fs.exists( path )
end
]]
end

if next( extract_assets ) then
    output = output .. "local extractAssets = "..serialise( extract_assets ) .. [[

for file, content in pairs( extractAssets ) do
    if not fs.exists( file ) then
        local h = fs.open( file, "w" )
        h.write( content )
        h.close()
    end
end
]]
end

local titanium = SETTINGS.TITANIUM.INSTALL
if titanium then
    output = output .. [[
if not fs.exists( "]] .. titanium .. [[" ) then
    local h = http.get "https://gist.githubusercontent.com/hbomb79/28de5f20b2053ed42cec855c778910d1/raw/titanium.min.lua"
    if h then
        local f = fs.open( "]] .. titanium .. [[", "w" )
        f.write( h.readAll() )
        f.close()

        h.close()
    else error "Failed to download Titanium" end
end
]]

    if SETTINGS.TITANIUM.AUTOLOAD then
        output = output .. 'if not _G.Titanium then dofile "'.. titanium .. '" end\n'
    end
elseif SETTINGS.TITANIUM.AUTOLOAD then
    print "WARNING: The Titanium module is set to auto load, however it's install location is not set. Use flag -ti=<location> to enable module installation"
end

if next( class_assets ) then
    output = output .. [[
for name, source in pairs( classSource ) do
    local className = name:gsub( "%..*", "" )
    if not Titanium.getClass( className ) then
        local output, err = loadstring( source, name )
        if not output or err then return error( "Failed to load Lua chunk. File '"..name.."' has a syntax error: "..tostring( err ), 0 ) end

        local ok, err = pcall( output )
        if not ok or err then return error( "Failed to execute Lua chunk. File '"..name.."' crashed: "..tostring( err ), 0 ) end

        local class = Titanium.getClass( className )
        if class then
            if not class:isCompiled() then class:compile() end
        else return error( "File '"..name.."' failed to create class '"..className.."'" ) end
    else
        print( "WARNING: Class " .. className .. " failed to load because a class with the same name already exists." )
    end
end
]]
end

local init = SETTINGS.INIT_FILE
if init then
    if vfs_assets[ init ] then
        output = output .. [[

local fn, err = VFS_ENV.loadstring( vfsAssets[ "]]..init..[[" ], "]] .. getName( init ) .. [[" )
if fn then fn()
else return error( "Failed to run file from bundle vfs: "..tostring( err ) ) end]]
    elseif extract_assets[ init ] then
        output = output .. "VFS_ENV.dofile \""..init.."\""
    else
        error("Init file '"..init.."' is invalid. Not found inside application bundle")
    end
else
    error("Failed to compile project. No init file specified (--init/-i)=path")
end

local handle = io.open( SETTINGS.OUTPUT_LOCATION, "w" )
handle:write( output )
handle:close()
