--[[
    Titanium class system
    Handles creation, compilation and spawning of classes

    Licensed under MIT (Harry Felton)
]]
classLib = {}
local classes, classReg, current, currentReg = {}, {}, false, false

local reserved = { super = true; __type = true; __instance = true; setMetaMethod = true; resolve = true; __current = true }

local getters = setmetatable( {}, { __index = function( self, name )
    self[ name ] = "get" .. name:sub( 1, 1 ):upper() .. name:sub( 2 )

    return self[ name ]
end })

local setters = setmetatable( {}, { __index = function( self, name )
    self[ name ] = "set"..name:sub(1, 1):upper()..name:sub(2)

    return self[ name ]
end })

local function throw( message, level )
    return error( "Titanium Class Exception: " .. ( message or "No error provided" ), type( level ) == "number" and level > 0 and level + 1 or 2 )
end

local function getClass( name, compiled )
    local class = classes[ name ]

    if not class then
        if MISSING_CLASS_LOADER then
            local oCurrent, oCurrentReg = current, currentReg
            current, currentReg = false, false

            MISSING_CLASS_LOADER( name )

            current, currentReg = oCurrent, oCurrentReg
            return ( not classes[ name ] and throw( "Failed to load class '"..name.."'. Class not found" ) ) or ( classes[ name ] and not classes[ name ]:isCompiled() and throw( "Failed to load class '"..name.."'. Class not compiled" ) ) or classes[ name ]
        else
            return throw( "Failed to load class '"..tostring( name ).."'. Class not found" )
        end
    elseif not class:isCompiled() then
        return throw( "Failed to load class '"..name.."'. Class not compiled" )
    end

    return class
end

local function isBuilding()
    if current or currentReg then
        return ( current and currentReg ) or throw("A class registry error has occured")
    end
    return false
end

local function propertyCatch( tbl )
    if type( tbl ) == "table" then
        if not isBuilding() then
            throw("Cannot implement trailing property. No class is being built")
        end

        for key, value in pairs( tbl ) do
            current[ key ] = value
        end
    elseif type( tbl ) ~= "nil" then
        throw("Unknown property trailing class declaration")
    end
end

local function deepCopy( source )
    if type( source ) == "table" then
        local copy = {}
        for key, value in next, source, nil do
            copy[ deepCopy( key ) ] = deepCopy( value )
        end
        return copy
    else
        return source
    end
end

local function compileSupers( base, targets )
    local inheritedKeys, inheritedAlias, superMatrix = {}, {}, {}
    local aliasPart = {}
    local function compileSuper( target, id )
        local factories = {}
        local targetType = target:type()
        local targetReg = classReg[ targetType ]

        for key, value in pairs( targetReg.raw ) do
            if not reserved[ key ] then
                local toInsert = value
                if type( value ) == "function" then
                    factories[ key ] = function( instance, raw, ... )
                        local old = instance:setSuper( id + 1 )
                        instance.raw.__current = targetType

                        local v = { value( instance, ... ) }
                        instance.raw.super = old

                        return unpack( v )
                    end
                    toInsert = factories[ key ]
                end

                inheritedKeys[ key ] = toInsert
            end
        end
        for alias, redirect in pairs( targetReg.alias ) do
            aliasPart[ alias ] = redirect
        end

        -- Handle inheritance
        for key, value in pairs( inheritedKeys ) do
            if type( value ) == "function" and not factories[ key ] then
                factories[ key ] = value
            end
        end

        superMatrix[ id ] = { factories, targetReg }
    end

    for id = #targets, 1, -1 do compileSuper( targets[ id ], id ) end

    local baseAlias = classReg[ base:type() ].alias
    for alias, redirect in pairs( aliasPart ) do
        if baseAlias[ alias ] == nil then
            baseAlias[ alias ] = redirect
        end
    end

    return inheritedKeys, function( instance )
        local matrix, matrixReady = {}
        local function generateMatrix( target, id )
            local superTarget, matrixTbl, matrixMt = superMatrix[ id ], {}, {}
            local factories, reg = superTarget[ 1 ], superTarget[ 2 ]

            matrixTbl.__type = reg.type

            local raw, owned, wrapCache, factory, upSuper = reg.raw, reg.ownedKeys, {}

            function matrixMt:__tostring()
                return "["..reg.type.."] Super #"..id.." of '"..instance.__type.."' instance"
            end
            function matrixMt:__newindex( k, v )
                if matrixReady or k ~= "super" then
                    throw("Cannot set keys on super. Illegal action.")
                else
                    upSuper = v
                end
            end
            function matrixMt:__index( k )
                factory = factories[ k ]
                if factory then
                    if not wrapCache[ k ] then wrapCache[ k ] = function( self, ... ) return factory( instance, raw, ... ) end end
                    return wrapCache[ k ]
                else
                    if k == "super" then
                        return upSuper
                    else
                        return throw("Cannot lookup value for key '"..k.."' on super. Illegal action.")
                    end
                end
            end
            function matrixMt:__call( ... )
                local init = self.__init__
                if type( init ) == "function" then
                    return init( ... )
                else
                    throw("Failed to execute super constructor. __init__ method not found")
                end
            end

            setmetatable( matrixTbl, matrixMt )
            return matrixTbl
        end

        local last = matrix
        for id = 1, #targets do
            last.super = generateMatrix( targets[ id ], id )
            last = last.super
        end

        martixReady = true
        return matrix
    end
end

local function compileConfiguration( targets )
    -- Generate a matrix, containing a configuration table for each step of the classes instantiation.
    local matrix = {}
    local function convertToPair( tbl )
        if type( tbl ) ~= "table" then return false end

        local newTbl = {}
        for i = 1, #tbl do
            newTbl[ tbl[ i ] ] = true
        end

        return newTbl
    end

    local function mergeSection( a, b )
        local merged = {}
        if type( a ) == "table" and type( b ) == "table" then
            merged = a

            for key in pairs( b ) do merged[ key ] = true end
        else
            printError("Invalid. A: "..type( a )..", B: "..type( b ))
        end

        return merged
    end

    local function processTarget( target, rollover )
        -- Merge this classes configuration with the current, without overwriting.
        local part = mergeSection( convertToPair( classReg[ target.__type ].meta.constructor.useProxy ), rollover )

        matrix[ target.__type ] = part

        return part
    end

    local base = processTarget( current, {} )
    for i = 1, #targets do
        base = processTarget( targets[ i ], base )
    end

    return matrix
end

local function compileCurrent()
    if not isBuilding() then
        throw("Cannot compile currently building class. No class is being built")
    end

    local raw, alias = currentReg.raw, currentReg.alias

    for target, _ in pairs( currentReg.mixin ) do
        local reg = classReg[ target ]

        -- Mixin raw keys
        for key, value in pairs( reg.raw ) do
            if not reserved[ key ] and not raw[ key ] then raw[ key ] = value end
        end

        -- Mixin alias
        for target, redirect in pairs( reg.alias ) do
            if not alias[ target ] then alias[ target ] = redirect end
        end
    end

    if currentReg.super then
        local supers = {}

        local last, c, newC = currentReg.super.target
        while last do
            c = getClass( last, true )

            table.insert( supers, c )
            newC = classReg[ c:type() ].super
            last = newC and newC.target or false
        end

        --TODO: configuration testing and integration.
        --compileConfiguration( supers )

        local keys
        keys, currentReg.super.matrix = compileSupers( current, supers )

        local wrappers = currentReg.super.wrappers
        for key, value in pairs( keys ) do
            if raw[ key ] == nil then
                if type( value ) == "function" then wrappers[ key ] = value else raw[ key ] = value end
            end
        end
    end
    currentReg.compiled, current, currentReg = true, false, false
end

local function spawn( target, ... )
    local targetReg = classReg[ target:type() ]
    if targetReg.abstract then
        throw("Failed to spawn instance of abstract class '"..target:type().."'. Illegal action.")
    end

    local instance, instanceMt, instanceRaw, instanceWrappers = {}, {}, deepCopy( targetReg.raw ), {}
    local hasSupers, superAmount, instanceType, alias, super = false, 0, target:type(), targetReg.alias, targetReg.super

    instanceRaw.__ID = string.sub( tostring( instanceRaw ), 8 )
    instanceRaw.__type = instanceType
    instanceRaw.__instance = true
    instanceRaw.__current = instanceType
    local initialised

    instance.raw = instanceRaw

    local supers = {}
    local function indexSupers( last, ID )
        while last.super do
            supers[ ID ] = last.super
            last = last.super
            ID = ID + 1
        end
    end

    local function createWrapper( key, value )
        instanceWrappers[ key ] = function( self, ... )
            local oSuper = self:setSuper( 1 )
            local v = value( instance, ... )
            instanceRaw.super = oSuper

            return v
        end
    end

    local setting, getting = {}, {}
    local function runProxyFunction( instance, keyName, proxyName, tbl, ... )
        local oSuper = instance:setSuper( 1 )

        tbl[ keyName ] = true
        local v = instanceRaw[ proxyName ]( instance, ... )
        tbl[ keyName ] = nil

        instanceRaw.super = oSuper
        return v
    end

    function instanceMt:__index( k )
        local k = alias[ k ] or k
        local getter = getters[ k ]

        if initialised and type( instanceRaw[ getter ] ) == "function" and not getting[ k ] then
            return runProxyFunction( self, k, getter, getting )
        else
            if instanceWrappers[ k ] then
                instanceRaw.__current = instanceType
                return instanceWrappers[ k ]
            else
                return instanceRaw[ k ]
            end
        end
    end

    function instanceMt:__newindex( k, v )
        local k = alias[ k ] or k

        if reserved[ k ] then
            throw( "Key name '"..k.."' is reserved." )
        end

        local setter = setters[ k ]
        if instanceWrappers[ setter ] and not setting[ k ] and initialised then
            runProxyFunction( self, k, setter, setting, v )
        else
            if type( v ) == "function" then
                createWrapper( k, v )
            else
                instanceRaw[ k ], instanceWrappers[ k ] = v, nil
            end
        end
    end

    function instanceMt:__tostring()
        return "Instance of '"..instanceType.."'"
    end

    local old
    function instanceRaw:setSuper( target )
        old, instanceRaw.super = instanceRaw.super, supers[ target ]
        return old
    end

    setmetatable( instance, instanceMt )

    local classOwned = targetReg.ownedKeys
    for key, value in pairs( instanceRaw ) do
        if classOwned[ key ] and type( value ) == "function" then createWrapper( key, value ) end
    end

    if super then
        hasSupers = true

        local matrix, wrappers = super.matrix, super.wrappers
        for key, value in pairs( wrappers ) do
            instanceRaw[ key ] = function( instance, ... ) return value( instance, instanceRaw, ... ) end
        end
        instanceRaw.super = targetReg.super.matrix( instance ).super

        indexSupers( instanceRaw, 1 )
    end

    local meta = targetReg.meta
    local isWhitelisted = meta.mode == "w"
    local targetTable = isWhitelisted and meta.whitelist or meta.blacklist

    function instanceRaw:setMetaMethod( method, fn )
        local method = "__"..method
        if ( isWhitelisted and not targetTable[ method ] ) or ( not isWhitelisted and targetTable[ method ] ) then
            return throw("Cannot set meta method '"..method.."'. Illegal action.")
        end

        instanceMt[ method ] = fn
    end

    function instanceRaw:resolve( ... )
        local current = instanceRaw.__current
        local args, config, raw = { ... }, classReg[ current ].meta.constructor, instanceRaw
        local configRequired, configOrdered, configTypes, configPrune = config.requiredArguments, config.orderedArguments, config.argumentTypes or {}, config.pruneMode

        local argumentsRequired = {}
        if configRequired then
            local target = type( configRequired ) == "table" and configRequired or configOrdered

            for i = 1, #target do argumentsRequired[ target[ i ] ] = true end
        end

        local orderedMatrix = {}
        for i = 1, #configOrdered do
            orderedMatrix[ configOrdered[ i ] ] = i
        end

        local usedIndexes = {}
        local function handleArgument( position, name, value )
            if configTypes[ name ] and type( value ) ~= configTypes[ name ] then
                return throw("Failed to resolve "..tostring( instance ).." constructor arguments. Invalid type for argument '"..name.."'. Type "..configTypes[ name ].." expected, "..type( value ).." was received.")
            end

            if position then usedIndexes[ position ] = true end
            argumentsRequired[ name ] = nil
            raw[ name ] = value
        end

        for iter, value in pairs( args ) do
            if configOrdered[ iter ] then
                handleArgument( iter, configOrdered[ iter ], value )
            elseif type( value ) == "table" then
                for key, v in pairs( value ) do
                    if orderedMatrix[ key ] or not configPrune then -- If we are not pruning parse the table anyway, we haven't been told to preserve unused arguments.
                        handleArgument( orderedMatrix[ key ], key, v )
                    end
                end
            elseif not configPrune then
                return throw("Failed to resolve "..tostring( instance ).." constructor arguments. Invalid argument found at ordered position "..iter..".")
            end
        end

        if next( argumentsRequired ) then
            return throw("Failed to resolve "..tostring( instance ).." constructor arguments. The following required arguments were not provided:\n\n"..(function()
                local str = ""
                for name, _ in pairs( argumentsRequired ) do
                    str = str .. "- "..name.."\n"
                end

                return str
            end)())
        end

        if configPrune then
            for i = #args, 1, -1 do
                if usedIndexes[ i ] then
                    table.remove( args, i )
                end
            end

            return unpack( args )
        end
    end

    setmetatable( instance, instanceMt )

    if type( instanceRaw.__init__ ) == "function" then instanceRaw.__init__( instance, ... ) end
    instanceRaw.__initialised, initialised = true, true

    return instance
end

function class( name )
    if isBuilding() then
        throw("Cannot begin construction of new class before currently building class '"..current:type().."' is compiled.")
    end

    if type( name ) ~= "string" then
        throw( "Class name '"..tostring( name ).."' is not valid. Class names must be a string." )
    elseif not name:find( "%a" ) then
        throw( "Class name '"..tostring( name ).."' is not valid. No alphabetic characters could be found.")
    elseif name:find( "%d" ) then
        throw( "Class name '"..name.."' is not valid. Class names cannot contain digits." )
    elseif classes[ name ] then
        throw( "A class with name '"..name.."' already exists." )
    elseif reserved[ name ] then
        throw( "System name '"..name.."' is reserved." )
    else
        local char = name:sub( 1, 1 )
        if char ~= char:upper() then
            throw( "Class name '"..name.."' is not valid. Class names must begin with an uppercase character.")
        end
    end

    local registryEntry = { type = name; raw = { __type = name }; mixin = {}; alias = {}; ownedKeys = {}; super = false; compiled = false; meta = { blacklist = { __index = true, __newindex = true }; whitelist = {}; mode = false } }
    classReg[ name ] = registryEntry

    local classMt = { __index = registryEntry.raw, __tostring = function() return ( registryEntry.compiled and "Compiled " or "" ) .. "Class '"..name.."'" end, __call = function( self, ... ) return self:spawn( ... ) end}

    function classMt:__newindex( key, value )
        if reserved[ key ] then
            throw( "Key name '"..key.."' is reserved." )
        elseif self:isCompiled() then
            throw( "Failed to set key on compiled class. Illegal action." )
        end

        registryEntry.raw[ key ] = value
        registryEntry.ownedKeys[ key ] = value == nil and nil or true
    end

    local class = {}
    function class.type()
        return name
    end

    function class.isCompiled()
        return registryEntry.compiled
    end

    function class.compile()
        compileCurrent()
    end

    function class:spawn( ... )
        if not registryEntry.compiled then
            throw("Cannot spawn instance of class '"..name.."'. The class has not been compiled.")
        end

        return spawn( self, ... )
    end

    setmetatable( class, classMt )

    classes[ name ] = class
    _G[ name ] = class

    current = class
    currentReg = registryEntry

    return propertyCatch
end

function extends( name )
    if not isBuilding() then
        throw("Cannot extend to target '"..name.."'. No class is being built.")
    end

    if currentReg.super then
        throw("Cannot extend to target '"..name.."'. The class '"..current:type().."' has already extended to '"..currentReg.super.."'.")
    else
        currentReg.super = { target = name; matrix = {}; wrappers = {} }
    end

    return propertyCatch
end

function mixin( name )
    if not isBuilding() then
        throw("Cannot mixin target '"..name.."'. No class is being built.")
    elseif currentReg.mixin[ name ] then
        throw("Cannot mixin target '"..name.."' to class '"..current:type().."'. The target has already been mixed in to this class.")
    else
        if not getClass( name, true ) then
            throw("Cannot mixin target '"..name.."' to class '"..current:type().."'. Failed to locate target class.")
        end

        currentReg.mixin[ name ] = true
    end

    return propertyCatch
end

function alias( target )
    if not isBuilding() then
        throw("Cannot add alias target. No class is being built.")
    end

    local tbl = ( type( target ) == "table" and target ) or ( type( _G[ target ] ) == "table" and _G[ target ] )
    if not tbl then
        throw("Failed to lookup alias target '"..tostring( target ).."' in global environment.")
    end

    local currentAlias = currentReg.alias
    for key, redirect in pairs( tbl ) do
        currentAlias[ key ] = redirect
    end

    return propertyCatch
end

function abstract()
    if not isBuilding() then
        throw("Cannot enforce abstract class policy. No class is being built.")
    end

    currentReg.abstract = true
    return propertyCatch
end

local function apply( str, tbl, invert )
    for item in str:gmatch("(%w+)[,]?") do
        tbl[ "__"..item ] = not invert or nil
    end
end

local function applySetting( mt, blacklist )
    if ( blacklist and mt.mode == "w" ) or ( not blacklist and mt.mode == "b" ) then
        return throw("Cannot "..( blacklist and "blacklist" or "whitelist" ).." meta methods. The class has applied a '"..( blacklist and "whitelist" or "blacklist" ).."' rule which cannot be used alongside the '"..(blacklist and "blacklist" or "whitelist").."' rule." )
    end

    mt.mode = blacklist and "b" or "w"
end

function blacklist( str )
    if not isBuilding() then
        throw("Cannot blacklist meta methods on building class. No class is being built.")
    end
    local mt = currentReg.meta

    applySetting( mt, true )
    apply( str, mt.blacklist )

    return propertyCatch
end

function unblacklist( str )
    if not isBuilding() then
        throw("Cannot unblacklist meta methods on building class. No class is being built.")
    end
    local mt = currentReg.meta

    applySetting( mt, true )
    apply( str, mt.blacklist, true )

    return propertyCatch
end

function whitelist( str )
    if not isBuilding() then
        throw("Cannot whitelist meta methods on building class. No class is being built.")
    end
    local mt = currentReg.meta

    applySetting( mt )
    apply( str, mt.whitelist )

    return propertyCatch
end

function configureConstructor( config )
    if not isBuilding() then
        throw("Cannot configure constructor of building class. No class is being built.")
    elseif type( config ) ~= "table" then
        throw("Cannot configure constructor of building class. Invalid constructor configuration")
    end

    currentReg.meta.constructor = config
end

-- Class Library
function classLib.getClass( name )
    return classes[ name ]
end

function classLib.getClasses()
    return classes
end

function classLib.isClass( target ) return type( target ) == "table" and target.__type and classes[ target.__type ] end

function classLib.isInstance( target ) return classLib.isClass( target ) and target.__instance end

function classLib.typeOf( target, classType, isInstance ) return ( ( isInstance and classLib.isInstance( target ) ) or ( not isInstance and classLib.isClass( target ) and not classLib.isInstance( target ) ) ) and target.__type == classType end

function classLib.setClassLoader( fn )
    if type( fn ) ~= "function" then throw( "Failed to set MISSING_CLASS_LOADER. Value '"..tostring( fn ).." ("..type( fn )..")' is invalid." ) end

    MISSING_CLASS_LOADER = fn
end

local function searchAndReplace( text, keyword )
    local start, stop, value = text:find( keyword.." (.[^%s]+)" )

    if start and stop and value then
        if value:find( "\"" ) or value:find( "\'" ) then return text end
        text = text:gsub( keyword.." "..value, keyword.." \""..value.."\"", 1 )
    end

    return text
end

local preprocessTargets = {"class", "extends", "alias", "mixin"}
function classLib.preprocess( text )
    for i = 1, #preprocessTargets do
        text = searchAndReplace( text, preprocessTargets[ i ] )
    end

    local name = text:match( "abstract class (\".[^%s]+\")" )
    if name then text = text:gsub( "abstract class "..name, "class "..name.." abstract()", 1 ) end

    return text
end
