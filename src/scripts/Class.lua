--[[
    Titanium class system
    Handles creation, compilation and spawning of classes

    Licensed under MIT (Harry Felton)
]]
classLib = {}
local classes, classReg, current, currentReg = {}, {}, false, false

local reserved = { super = true; }

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
        return ( current and currentReg and true ) or throw("A class registry error has occured")
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
    local baseAlias = classReg[ base:type() ].alias
    local function compileSuper( target, id )
        local factories = {}
        local targetReg = classReg[ target:type() ]

        for key, value in pairs( targetReg.raw ) do
            if not reserved[ key ] then
                local toInsert = value
                if type( value ) == "function" then
                    factories[ key ] = function( instance, raw, ... )
                        local old = instance:setSuper( id + 1 )
                        local v = { value( instance, ... ) }
                        instance.raw.super = old

                        return unpack( v )
                    end
                    toInsert = factories[ key ]
                end

                inheritedKeys[ key ] = toInsert
            end
        end
        for alias, redirect in pairs( targetReg.alias ) do baseAlias[ alias ] = redirect end

        -- Handle inheritance
        for key, value in pairs( inheritedKeys ) do
            if type( value ) == "function" and not factories[ key ] then
                factories[ key ] = value
            end
        end

        superMatrix[ id ] = { factories, targetReg }
    end

    for id = #targets, 1, -1 do compileSuper( targets[ id ], id ) end

    return inheritedKeys, function( instance )
        local matrix, matrixReady = {}
        local function generateMatrix( target, id )
            local superTarget, matrixTbl, matrixMt = superMatrix[ id ], {}, {}
            local factories, reg = superTarget[ 1 ], superTarget[ 2 ]

            local raw, owned, wrapCache, factory, upSuper = reg.raw, reg.ownedKeys, {}

            function matrixMt:__tostring()
                return "["..reg.type.."] Super #"..id.." of '"..instance:type().."' instance"
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
    local initialised, hasSupers, superAmount, instanceType, alias, super = false, false, 0, target:type(), targetReg.alias, targetReg.super

    instanceRaw.__ID = string.sub( tostring( instanceRaw ), 8 )
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

        if type(instanceRaw[ getter ]) == "function" and not getting[ k ] and initialised then
            runProxyFunction( self, k, getter, getting )
        else
            if instanceWrappers[ k ] then
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
    function instance:setSuper( target )
        old, instanceRaw.super = instanceRaw.super, supers[ target ]
        return old
    end

    function instance:isInitialised() return initialised end

    function instance:type() return instanceType end

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

    if type( instanceRaw.__init__ ) == "function" then instanceRaw.__init__( instance, ... ) end
    initialised = true

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
        throw( "System name '"..name.."' is reserved" )
    else
        local char = name:sub( 1, 1 )
        if char ~= char:upper() then
            throw( "Class name '"..name.."' is not valid. Class names must begin with an uppercase character.")
        end
    end

    local registryEntry = { type = name; raw = {}; mixin = {}; alias = {}; ownedKeys = {}; super = false; compiled = false; }
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

    function class.getRegistry()
        return registryEntry
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
        throw("Cannot extend to target '"..name.."'. The class '"..current:type().."' has already extended to '"..currentReg.super.."'")
    else
        currentReg.super = { target = name; matrix = {}; wrappers = {} }
    end

    return propertyCatch
end

function mixin( name )
    if not isBuilding() then
        throw("Cannot mixin target '"..name.."'. No class is being built")
    elseif currentReg.mixin[ name ] then
        throw("Cannot mixin target '"..name.."' to class '"..current:type().."'. The target has already been mixed in to this class.")
    else
        currentReg.mixin[ name ] = true
    end

    return propertyCatch
end

function alias( target )
    if not isBuilding() then
        throw("Cannot add alias target. No class is being built")
    end

    local tbl = ( type( target ) == "table" and target ) or ( type( _G[ target ] ) == "table" and _G[ target ] )
    if not tbl then
        throw("Failed to lookup alias target '"..tostring( target ).."' in global environment")
    end

    local currentAlias = currentReg.alias
    for key, redirect in pairs( tbl ) do
        currentAlias[ key ] = redirect
    end

    return propertyCatch
end

function abstract()
    currentReg.abstract = true
    return propertyCatch
end

-- Class Library
function classLib.getClass( name )
    return classes[ name ]
end

function classLib.getClasses()
    return classes
end

function classLib.isClass( target ) return type( target ) == "table" and target.__type and classes[ target.__type ] and classes[ target.__type ].__class end

function classLib.isInstance( target ) return classLib.isClass and target.__instance end

function classLib.typeOf( target, classType, isInstance ) return ( ( isInstance and classLib.isInstance( target ) ) or ( not isInstance and classLib.isClass( target ) ) ) and target.__type == classType end

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
