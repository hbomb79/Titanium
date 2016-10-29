--[[
    Titanium Manager

    The Titanium Manager is a versatile tool that can be used to install and update Titanium installations.

    Usage: `manager.lua install <path> [tag] [minify] [versionPath] [silent]`
        OR `manager.lua update <path> [minify] [versionPath] [silent]`
]]

local args = { ... }

--[[ Constants ]]--
-- Credit to https://github.com/Team-CC-Corp/Grin/blob/master/lib/json for this API
local JSON_API = [[local ba={["\n"]="\\n",["\r"]="\\r",["\t"]="\\t",["\b"]="\\b",["\f"]="\\f",["\""]="\\\"",["\\"]="\\\\"}
local function ca(cb)local db=0;for _c,ac in pairs(cb)do
if type(_c)~="number"then return false elseif _c>db then db=_c end end;return db==#cb end
local da={['\n']=true,['\r']=true,['\t']=true,[' ']=true,[',']=true,[':']=true}
function removeWhite(cb)while da[cb:sub(1,1)]do cb=cb:sub(2)end;return cb end
local function _b(cb,db,_c,ac)local bc=""
local function cc(_d)bc=bc.. ("\t"):rep(_c).._d end
local function dc(_d,ad,bd,cd,dd)bc=bc..ad;if db then bc=bc.."\n"_c=_c+1 end
for __a,a_a in cd(_d)do cc("")
dd(__a,a_a)bc=bc..","if db then bc=bc.."\n"end end;if db then _c=_c-1 end
if bc:sub(-2)==",\n"then
bc=bc:sub(1,-3).."\n"elseif bc:sub(-1)==","then bc=bc:sub(1,-2)end;cc(bd)end
if type(cb)=="table"then
assert(not ac[cb],"Cannot encode a table holding itself recursively")ac[cb]=true
if ca(cb)then
dc(cb,"[","]",ipairs,function(_d,ad)bc=bc.._b(ad,db,_c,ac)end)else
dc(cb,"{","}",pairs,function(_d,ad)
assert(type(_d)=="string","JSON object keys must be strings",2)bc=bc.._b(_d,db,_c,ac)bc=bc..
(db and": "or":").._b(ad,db,_c,ac)end)end elseif type(cb)=="string"then
bc='"'..cb:gsub("[%c\"\\]",ba)..'"'elseif type(cb)=="number"or type(cb)=="boolean"then
bc=tostring(cb)else
error("JSON only supports arrays, objects, numbers, booleans, and strings",2)end;return bc end;function encode(cb)return _b(cb,false,0,{})end;function encodePretty(cb)
return _b(cb,true,0,{})end;local ab={["\\/"]="/"}
for cb,db in pairs(ba)do ab[db]=cb end;function parseBoolean(cb)
if cb:sub(1,4)=="true"then return true,removeWhite(cb:sub(5))else return
false,removeWhite(cb:sub(6))end end;function parseNull(cb)return nil,
removeWhite(cb:sub(5))end
local bb={['e']=true,['E']=true,['+']=true,['-']=true,['.']=true}
function parseNumber(cb)local db=1;while
bb[cb:sub(db,db)]or tonumber(cb:sub(db,db))do db=db+1 end
local _c=tonumber(cb:sub(1,db-1))cb=removeWhite(cb:sub(db))return _c,cb end
function parseString(cb)cb=cb:sub(2)local db=""
while cb:sub(1,1)~="\""do local _c=cb:sub(1,1)
cb=cb:sub(2)assert(_c~="\n","Unclosed string")if _c=="\\"then
local ac=cb:sub(1,1)cb=cb:sub(2)
_c=assert(ab[_c..ac],"Invalid escape character")end;db=db.._c end;return db,removeWhite(cb:sub(2))end
function parseArray(cb)cb=removeWhite(cb:sub(2))local db={}local _c=1
while
cb:sub(1,1)~="]"do local ac=nil;ac,cb=parseValue(cb)db[_c]=ac;_c=_c+1;cb=removeWhite(cb)end;cb=removeWhite(cb:sub(2))return db,cb end
function parseObject(cb)cb=removeWhite(cb:sub(2))local db={}
while cb:sub(1,1)~="}"do
local _c,ac=nil,nil;_c,ac,cb=parseMember(cb)db[_c]=ac;cb=removeWhite(cb)end;cb=removeWhite(cb:sub(2))return db,cb end;function parseMember(cb)local db=nil;db,cb=parseValue(cb)local _c=nil;_c,cb=parseValue(cb)
return db,_c,cb end
function parseValue(cb)
local db=cb:sub(1,1)
if db=="{"then return parseObject(cb)elseif db=="["then return parseArray(cb)elseif
tonumber(db)~=nil or bb[db]then return parseNumber(cb)elseif cb:sub(1,4)=="true"or
cb:sub(1,5)=="false"then return parseBoolean(cb)elseif db=="\""then return
parseString(cb)elseif cb:sub(1,4)=="null"then return parseNull(cb)end;return nil end
function decode(cb)cb=removeWhite(cb)t=parseValue(cb)return t end
function decodeFromFile(cb)local db=assert(fs.open(cb,"r"))
local _c=decode(db.readAll())db.close()return _c end]]

local JSON = setmetatable( {}, { __index = _G } )
select( 1, load( JSON_API, "JSON_API", "t", JSON ) )()

local WIDTH, HEIGHT = term.getSize()
local MODE = args[ 1 ]
local PATH = args[ 2 ]

local TAG, MINIFY, VERSION_PATH, SILENT
if MODE == "install" then
    TAG, MINIFY, VERSION_PATH, SILENT = args[ 3 ], args[ 4 ], args[ 5 ] or ".titanium-version", args[ 6 ]
elseif MODE == "update" then
    MINIFY, VERSION_PATH, SILENT = args[ 3 ], args[ 4 ] or ".titanium-version", args[ 5 ]
elseif MODE == "help" then
    textutils.pagedPrint([[
To install Titanium:
manager.lua install <path> [tag] [minify] [versionPath] [silent]

To update:
manager.lua update <path> [minify] [versionPath] [silent]

To show this menu:
manager.lua help

If minify, minified builds will be downloaded if available

If versionPath, the path given will be used to get and set version information

If silent, no output to screen unless an exception occurs
]])

return
end

if MINIFY and MINIFY:lower() == "false" then MINIFY = false end
if SILENT and SILENT:lower() == "false" then SILENT = false end
if VERSION_PATH and VERSION_PATH:lower() == "false" then VERSION_PATH = ".titanium-version" end
if TAG and TAG:lower() == "false" then TAG = false end

local function exception( errorMessage )
    error( "Failed to manage Titanium installation: " .. errorMessage, 0 )
end

if not ( MODE and PATH ) then
    exception "Missing mode and path arguments. See `manager.lua help`"
end

local function posOut( x, y, text, fg, bg )
    if SILENT then return end
    term.setCursorPos( x, y )

    if fg then term.setTextColour( fg ) end
    if bg then term.setBackgroundColour( bg ) term.clearLine() end

    print( text )
end

local function centreOut( y, text, ... )
    if type( text ) == "table" then
        for i = 1, #text do
            posOut( math.ceil( ( WIDTH / 2 ) - ( #text[ i ] / 2 ) ), y + ( i - 1 ), text[ i ], ... )
        end
    else
        posOut( math.ceil( ( WIDTH / 2 ) - ( #text / 2 ) ), y, text, ... )
    end
end

local function clr( bg, fg )
    if SILENT then return end
    term.setBackgroundColour( bg or 1 )
    term.setTextColour( fg or 128 )

    term.clear()

    posOut( 1, 1, "Titanium Manager", 1, colours.grey )
    term.setCursorPos( 1, 2 )
    term.clearLine()
end

local function clearLine( y, bg )
    if SILENT then return end
    term.setCursorPos( 1, y )
    if bg then term.setBackgroundColour( bg ) end

    term.clearLine()
end

local function promptVersion( x, y )
    term.setCursorPos( x, y )

    term.setTextColour( 128 )
    term.setBackgroundColour( 256 )
    local tag = read()

    term.setTextColour( 128 )
    term.setBackgroundColour( 1 )

    return tag
end

local function getTags()
    local h = http.get "http://harryfelton.web44.net/titanium/serve-build.php?list"
    if not h then exception "Failed to fetch tag information. Please try again later" end

    local tags = JSON.decode( h.readAll() )
    h.close()

    return tags
end

local function selectTag( y )
    centreOut( y, "Fetching Tag Information", 256, 1 )
    local tags = getTags()

    local offset, height, changed, vh = 1, #tags, true, HEIGHT - y + 1
    while true do
        local old = offset
        if changed then
            local drawOffset = offset >= vh and vh - offset - 1 or 0

            for i = 1, height do
                local offsetI = i + drawOffset
                if offsetI > 0 and offsetI < vh then
                    if offset == i then
                        centreOut( offsetI + y - 1, "\16"..tags[ i ].."\17", colours.cyan, 1 )
                    else
                        centreOut( offsetI + y - 1, tags[ i ], 256, 1 )
                    end
                end
            end

            changed = false
        end

        local event = { os.pullEvent "key" }
        if event[ 2 ] == keys.down then
            offset = offset + 1
            if offset > height then offset = 1 end
        elseif event[ 2 ] == keys.up then
            offset = offset - 1
            if offset < 1 then offset = height end
        elseif event[ 2 ] == keys.enter then
            return tags[ offset ]
        end

        changed = old ~= offset
    end
end

local function finished()
    if SILENT then return end

    clr()
    posOut( WIDTH - 9, 1, "Up-to-date", 256 )
    centreOut( 7, { "Your Titanium installation is", "up-to-date" }, colours.cyan, 1 )
    centreOut( 10, "Click anywhere to exit", 256 )

    os.pullEvent "mouse_click"
end

local function install( tag )
    clr()
    posOut( WIDTH - 13, 1, "Fetching build", 256 )

    centreOut( 7, { "Please wait while we gather", "build information about", "tag '"..tag.."'" }, colours.cyan, 1 )
    centreOut( 11, "This might take a while", 256, 1 )

    local h = http.get( "http://harryfelton.web44.net/titanium/serve-build.php?tag="..tag )
    if not h then exception("Failed to fetch build information for tag '"..tag.."'") end

    local builds = JSON.decode( h.readAll() )
    h.close()

    if builds.message then
        if builds.code == 1 or builds.code == 3 then
            exception("Invalid tag '"..tag.."': " .. builds.message)
        else exception("Unknown error: " .. builds.message) end
    end

    local build = MINIFY and builds["titanium.min.lua"] or builds["titanium.lua"]
    local f = fs.open( PATH, "w" )
    f.write( build )
    f.close()

    f = fs.open( VERSION_PATH, "w" )
    f.write( tag )
    f.close()

    finished()
end

local function update()
    clr()
    posOut( WIDTH - 12, 1, "Fetching tags", 256 )

    centreOut( 7, { "Please wait while we determine", "the latest version of Titanium" }, colours.cyan, 1 )
    centreOut( 11, "This shouldn't take long", 256, 1 )

    local tags = getTags()

    if not fs.exists( VERSION_PATH ) or not fs.exists( PATH ) then
        install( tags[ 1 ] )
    else
        local h = fs.open( VERSION_PATH, "r" )
        local version = h.readAll()
        h.close()

        if version == tags[ 1 ] then
            finished()
        else
            install( tags[ 1 ] )
        end
    end
end

clr()

if MODE == "install" then
    posOut( WIDTH - 6, 1, "Install", 256 )
    centreOut( 5, {
        "To install Titanium, select",
        "the version you wish to download",
        "and hit enter."
    }, colours.cyan, 1 )

    if not TAG and SILENT then
        exception "No tag specified. Cannot display tag selector when silenced. See `manager.lua help`"
    end

    install( TAG or selectTag( 10 ) )
elseif MODE == "update" then
    update()
else
    exception("Unknown manager mode '"..MODE.."'. See `manager.lua help`")
end
