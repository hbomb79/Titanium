--[[
    Titanium Class System

    Description: This file manages Titanium's classes and their respective instances.
    Version: 0.1 (Incomplete)

    - Harry Felton (HexCodeCC) -
]]
local sub, find = string.sub, string.find
local classes, current, last = {}, false, false
_G.classLib = {}

local reserved, allowRawAccess = {
    __super = true;
    __ownedIndexes = true;
    __mixins = true;
    __aliases = true;
    __interfaces = true;
}, false


local getters = setmetatable( {}, { __index = function( self, name )
    self[ name ] = "get" .. name:sub( 1, 1 ):upper() .. name:sub( 2 )

    return self[ name ]
end })

local setters = setmetatable( {}, { __index = function( self, name )
    self[ name ] = "set"..name:sub(1, 1):upper()..name:sub(2)

    return self[ name ]
end })


--[[
    @local
    @desc Throws an exception prefixed with 'ClassLib Exception: '.
    @param message <string>
    @return <error>
]]
local function throw( message )
    return error( "ClassLib Exception: " .. tostring( message ), 2 )
end


--[[
    @local
    @desc Attempts to retrieve a class. If its not found then Titanium will try to load it using the missing class loader.
    @param
        name <string>
        compiled <boolean>
        notFoundError <string>
        notCompiledError <string>

    @return <class base> || error
]]
local function getClass( name, compiled, notFoundError, notCompiledError )
    local class = classes[ name ]

    if not class then
        if MISSING_CLASS_LOADER then
            return loadRequiredClass( name )
        else
            return throw( notFoundError )
        end
    elseif not class:isCompiled() then
        return throw( notCompiledError )
    end

    return class
end


--[[
    @local
    @desc Gets the raw content from a class base
    @param base <class base>
    @return <table>
]]
local function getRawContent( base )
    allowRawAccess = true
    local raw = base:getRaw()
    allowRawAccess = false

    return raw
end


--[[
    @local
    @desc Creates a deep copy of a variable. Mainly for tables. The new table removed contains no references to the source table.
    @param source <any>
    @return <any>
]]
local function deepCopy( source )
    local orig_type = type( source )
    local copy
    if orig_type == 'table' then
        copy = {}
        for key, value in next, source, nil do
            copy[ deepCopy( key ) ] = deepCopy( value )
        end
    else
        copy = source
    end
    return copy
end


--[[
    @local
    @desc Creates a compiled super matrix, this is then stored on class bases at compilation.
    @param name <string>
]]
local function compileSuper( base, target, aliases, inherited, superID )
    local superID = superID or 1
    local super, superMt = {}, {}
    local targetRaw = getRawContent( getClass( target, true, "Failed to compile base class '"..tostring( base ).."'. Super target '"..tostring( target ).."' couldn't be found.", "Failed to compile base class '"..tostring( base ).."'. Super target '"..tostring( target ).."' is not compiled") )

    local totalAliases, totalInherited = aliases or {}, inherited or {}

    local factories = {}
    for key, value in pairs( targetRaw ) do
        if not reserved[ key ] then
            if type( value ) == "function" then
                factories[ key ] = function( instance, raw, ... )
                    local oldSuper = instance.super
                    instance:setSuper( superID + 1 )

                    local returnData = { raw[ key ]( instance, ... ) }

                    instance.super = oldSuper

                    return unpack( returnData )
                end
                if totalInherited[ key ] == nil then
                    totalInherited[ key ] = factories[ key ]
                end
            else
                if totalInherited[ key ] == nil then
                    totalInherited[ key ] = value
                end
            end
        elseif key == "__aliases" then
            for target, redirect in pairs( value ) do
                if not totalAliases[ target ] then
                    totalAliases[ target ] = redirect
                end
            end
        end
    end

    if targetRaw.__super then
        super.super = compileSuper( base, targetRaw.__super, totalAliases, totalInherited, superID + 1 )
    end

    function super:spawn( instance )
        -- Create a custom instance of this super matrix for this instance in particular.
        local raw = deepCopy( targetRaw )
        local proxy, proxyMt = {}, {}

        local owned = raw.__ownedIndexes

        local factoryCache, wrapCache = {}, {}
        local factory
        function proxyMt:__index( k )
            if factories[ k ] then
                if not factoryCache[ k ] then
                    factoryCache[ k ] = owned[ k ] and factories[ k ] or raw[ k ]
                end

                factory = factoryCache[ k ]

                if not wrapCache[ k ] then
                    wrapCache[ k ] = function( self, ... )
                        local v
                        if owned[ k ] then
                            v = { factory( instance, raw, ... ) }
                        else
                            v = { factory( instance, ... ) }
                        end

                        return unpack( v )
                    end
                end
                return wrapCache[ k ]
            elseif raw[ k ] then
                throw( "Non-function values cannot be retrieved from super." )
            end
        end

        function proxyMt:__newindex( k )
            throw( "Failed to set key '"..k.."'. Setting keys on super is not allowed" )
        end

        proxyMt.__tostring = function()
            return "Super #"..superID.." of "..tostring( instance )
        end

        setmetatable( proxy, proxyMt )
        return proxy
    end

    return super, totalAliases, totalInherited
end


--[[
    @local
    @desc Compiles the class base by combining the classes super classes, mixins and setting aliases
]]
local function compile()
    local raw = getRawContent( current )
    if not current then
        throw( "Cannot compile class because no class is being created" )
    end

    -- Handle mixins
    local mixins, mixin, mixinClass, mixinRaw = raw.__mixins
    for i = 1, #mixins do
        mixin = mixins[ i ]

        mixinClass = getClass( mixin, true, "Failed to mixin target '"..mixin.."'. The class couldn't be found", "Failed to mixin target '"..mixin.."'. The class is not compiled" )
        mixinRaw = getRawContent( mixinClass )

        for key, value in pairs( mixinRaw ) do
            if not current[ key ] then
                current[ key ] = value
            end
        end
    end

    -- Handle supers
    if raw.__extensionTarget then
        local total, aliases, inherited = raw.__aliases
        raw.__super, aliases, inherited = compileSuper( current, raw.__extensionTarget )

        for alias, redirect in pairs( aliases ) do
            if not total[ alias ] then total[ alias ] = redirect end
        end
        for key, value in pairs( inherited ) do
            if not raw[ key ] then current[ key ] = value end
        end
        raw.__extensionTarget = false
    end
end


--[[
    @local
    @desc Spawn an instance of a compiled class base
    @param name <string>
    @return <instance>
]]
local function spawn( name, ... )
    local instanceRaw = deepCopy( getRawContent( getClass( name ) ) )
    local instance, instanceMt = {}, {}

	instanceRaw.__ID = string.sub( tostring( instance ), 8)

    local alias = instanceRaw.__aliases

    local supers = {}
    local function indexSupers( last, ID )
        local ID = ID or 1
        if last.super then
            supers[ ID ] = last.super

            indexSupers( last.super, ID + 1 )
        end
    end

    function instance:setSuper( ID )
        instanceRaw.super = supers[ ID ]
    end

    local getting, setting = {}, {}
    function instanceMt:__index( k )
        local k = alias[ k ] or k

        local getter = getters[ k ]
        if type(instanceRaw[ getter ]) == "function" and not getting[ k ] then
            local oSuper = instanceRaw.super
            self:setSuper( 1 )

            getting[ k ] = true
            local v = { instanceRaw[ getter ]( self ) }
            getting[ k ] = nil

            instanceRaw.super = oSuper

            return unpack( v )
        else
            return instanceRaw[ k ]
        end
    end

    function instanceMt:__newindex( k, v )
        local k = alias[ k ] or k

        local setter = setters[ k ]
        if type(instanceRaw[ setter ]) == "function" and not setting[ k ] then
            local oSuper = instanceRaw.super
            self:setSuper( 1 )

            setting[ k ] = true
            instanceRaw[ setter ]( self )
            setting[ k ] = nil

            instanceRaw.super = oSuper
        else
            instanceRaw[ k ] = v
        end
    end
    instanceMt.__tostring = function()
        return "[Instance] "..name
    end

    if instanceRaw.__super then
        instanceRaw.super = instanceRaw.__super:spawn( instance )

        instanceRaw.__super = nil

        indexSupers( instance )
    end

    setmetatable( instance, instanceMt )

    if type( instanceRaw.__init__ ) == "function" then instanceRaw.__init__( instance, ... ) end
    return instance
end


--[[
    @local
    @desc Catches a table of arguments following a class declaration. The key-value pairs from this table are added to the current class.
    @param tbl <table>
]]
local function argumentCatcher( tbl )
    if type( tbl ) == "table" then
        for key, value in pairs( tbl ) do
            current[ key ] = value
        end
    elseif tbl then
        throw( "Argument catcher caught invalid trailing identifier '"..tostring( tbl ).." ("..type( tbl )..")'" )
    end
end


--[[
    @global
    @desc Creates a class base which, once compiled can be instantiated.
    @param name <string>
    @return argumentCatcher <function>
]]
_G.class = function( name )
    if type( name ) ~= "string" then
        throw( "Class name '"..tostring( name ).."' is not valid. Class names must be a string." )
    elseif not find( name, "%a" ) then
        throw( "Class name '"..tostring( name ).."' is not valid. No letters could be found.")
    elseif find( name, "%d" ) then
        throw( "Class name '"..name.."' is not valid. Class names cannot contain digits." )
    elseif classes[ name ] then
        throw( "A class with name '"..name.."' already exists." )
    elseif reserved[ name ] then
        throw( "System name '"..name.."' is reserved" )
    else
        local char = sub( name, 1, 1 )
        if char ~= char:upper() then
            throw( "Class name '"..name.."' is not valid. Class names must begin with an uppercase character.")
        end

        if current then
            throw( "Cannot create class base, class '"..tostring( current ).."' is already being created" )
        end
    end

    local isPhysical, isCompiled, isAbstract = true, false, false
    local base, proxyMt = { __ownedIndexes = {}, __aliases = {}, __mixins = {}, __interfaces = {} }, {}

    local ownedIndexes, aliases, mixins, interfaces = base.__ownedIndexes, base.__aliases, base.__mixins, base.__interfaces

    -- Create our proxy (public class interface)
    local proxy = setmetatable( {}, proxyMt )

    function proxy:compile()
        if isCompiled then
            throw( "Class base '"..name.."' is already compiled" )
        end

        compile()
        isCompiled = true

        last = current
        current = nil
    end

    function proxy:isCompiled() return isCompiled end

    function proxy:spawn( ... )
        if not isCompiled then
            throw( "Cannot spawn instance of un-compiled class base" )
        elseif isAbstract then
            throw( "Cannot spawn abstract class base" )
        end

        return spawn( name, ... )
    end

    function proxy:abstract( bool )
        if isCompiled then throw( "Cannot adjust abstract state of class base once compiled." ) end

        isAbstract = bool
    end

    function proxy:isAbstract() return isAbstract end

    function proxy:mixin( target )
        insert( mixins, target )
    end

    function proxy:implement( target )
        insert( interfaces, target )
    end

    function proxy:addAlias( target )
        local tbl
        if type( target ) == "table" then
            tbl = target
        elseif type( _G[ target ] ) == "table" then
            tbl = _G[ target ]
        end

        for key, value in pairs( tbl ) do
            aliases[ key ] = value
        end
    end

    function proxy:extend( target )
        if isCompiled then
            throw( "Cannot set extend target of class base once compiled." )
        elseif base.__extensionTarget then
            throw( "Cannot set multiple supers on class base." )
        end

        base.__extensionTarget = target
    end

    function proxy:setVirtualKey( k, v )
        isPhysical = false
        self[ k ] = v
        isPhysical = true
    end

    function proxy:getRaw()
        if not allowRawAccess then throw( "Cannot access raw content of a class base without permissions" ) end

        return base
    end

    -- Set the proxy to use our metatable
    proxyMt.__index = base
    proxyMt.__tostring = function() return (isCompiled and "Compiled " or "") .. "Base ["..name.."]" end
    proxyMt.__call = proxy.spawn
    function proxyMt:__newindex( k, v )
        if reserved[ k ] then
            throw( "Key name '"..k.."' is reserved." )
        elseif isCompiled then
            throw( "Cannot set value '"..tostring( v ).."' to key '"..k.."'. The class base '"..name.."' has been compiled." )
        end

        base[ k ] = v
        if isPhysical then
            ownedIndexes[ k ] = v ~= nil and true or nil
        end
    end

    -- make this proxy available
    current = proxy
    _G[ name ] = current
    classes[ name ] = current

    -- catch any class arguments that follow the declaration
    return argumentCatcher
end


--[[
    @global
    @desc Returns a class named 'name' if present
    @param name <string>
    @return [class base]
]]
function classLib.getClass( name )
    return classes[ name ]
end


--[[
    @global
    @desc Returns the classes table
    @return <table>
]]
function classLib.getClasses()
    return classes
end


--[[
    @global
    @desc Returns true if the target object is a class
    @param target [testFor - any]
    @return <boolean>
]]
function classLib.isClass( target ) return type( target ) == "table" and target.__type and classes[ target.__type ] and classes[ target.__type ].__class end


--[[
    @global
    @desc Returns true if the target object is a class instance
    @param target [testFor - any]
    @return <boolean>
]]
function classLib.isInstance( target ) return classLib.isClass and target.__instance end


--[[
    @global
    @desc Returns true if the target object is of type 'classType'. If 'isInstance' is true then it will be instance checked too
    @param
        target [testFor - any]
        classType <string>
        isInstance [boolean]
    @return <boolean>
]]
function classLib.typeOf( target, classType, isInstance ) return ( ( isInstance and classLib.isInstance( target ) ) or ( not isInstance and classLib.isClass( target ) ) ) and target.__type == classType end


--[[
    @global
    @desc Sets the class loader Titanium will use when a class that isn't loaded is used.
    @param fn <function>
]]
function classLib.setClassLoader( fn )
    if type( fn ) ~= "function" then throw( "Failed to set MISSING_CLASS_LOADER. Value '"..tostring( fn ).." ("..type( fn )..")' is invalid." ) end

    MISSING_CLASS_LOADER = fn
end


--[[
    @local
    @desc Performs the pre-processing of files by searching for keywords followed by values.
    @param
        text <string>
        keyword <string>
    @return <string>
]]
local function searchAndReplace( text, keyword )
    local start, stop, value = find( text, keyword.." (.[^%s]+)")

    if start and stop and value then
        if find( value, "\"") or find( value, "\'" ) then return text end
        text = text:gsub( keyword.." "..value, keyword.." \""..value.."\"", 1 )
    end

    return text
end


--[[
    @global
    @desc Performs pre-processing of a file, searches for class, extends, alias and mixin keywords.
    @param text <string>
    @return <string>
]]
local preprocessTargets = {"class", "extends", "alias", "mixin"}
function classLib.preprocess( text )
    for i = 1, #preprocessTargets do
        text = searchAndReplace( text, preprocessTargets[ i ] )
    end

    local name = text:match( "abstract class (\".[^%s]+\")" )
    if name then text = text:gsub( "abstract class "..name, "class "..name.." abstract()", 1 ) end

    return text
end


--[[
    @local
    @desc Throws an error 'message' is current is not defined. Mainly for code reuse with below global functions
    @param
        message <string>
        manual [string]
]]
local function throwIfNotCurrent( message, manual )
    if not current then return throw( message .. ( manual or " No class is being created" ) ) end
end


--[[
    @global
    @desc Used to extend currently building class to the target
    @param target <string>
    @return <function>
]]
_G.extends = function( target )
    throwIfNotCurrent( "Cannot extend to target '"..tostring( target ).."'." )
    current:extend( target )

    return argumentCatcher
end


--[[
    @global
    @desc Used to mix the currently building class with the target
    @param target <string>
    @return <function>
]]
_G.mixin = function( target )
    throwIfNotCurrent( "Cannot mixin target class '"..tostring( target ).."'." )
    current:mixin( target )

    return argumentCatcher
end


--[[
    @global
    @desc Used to add alias redirects to the currently building class
    @param target <string>
    @return <function>
]]
_G.alias = function( target )
    throwIfNotCurrent( "Cannot add alias redirects." )
    current:addAlias( target )

    return argumentCatcher
end

--[[
    @global
    @desc Used to make the currently building class abstract (cannot be instantiated)
    @return <function>
]]
_G.abstract = function()
    throwIfNotCurrent( "Cannot adjust abstract property." )
    current:abstract( true )

    return argumentCatcher
end
