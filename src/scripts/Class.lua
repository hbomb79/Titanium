--[[
    Titanium Class System - Version 1.1

    Copyright (c) Harry Felton 2016
]]

local classes, classRegistry, currentClass, currentRegistry = {}, {}
local reserved = {
    static = true,
    super = true,
    __type = true,
    isCompiled = true,
    compile = true
}

local missingClassLoader

local getters = setmetatable( {}, { __index = function( self, name )
    self[ name ] = "get" .. name:sub( 1, 1 ):upper() .. name:sub( 2 )

    return self[ name ]
end })

local setters = setmetatable( {}, { __index = function( self, name )
    self[ name ] = "set"..name:sub(1, 1):upper()..name:sub(2)

    return self[ name ]
end })

local isNumber = {}
for i = 0, 15 do isNumber[2 ^ i] = true end

--[[ Constants ]]--
local ERROR_BUG = "\nPlease report this via GitHub @ hbomb79/Titanium"
local ERROR_GLOBAL = "Failed to %s to %s\n"
local ERROR_NOT_BUILDING = "No class is currently being built. Declare a class before invoking '%s'"

--[[ Helper functions ]]--
local function throw( ... )
    return error( table.concat( { ... }, "\n" ) , 2 )
end

local function verifyClassEntry( target )
    return type( target ) == "string" and type( classes[ target ] ) == "table" and type( classRegistry[ target ] ) == "table"
end

local function verifyClassObject( target, autoCompile )
    if not Titanium.isClass( target ) then
        return false
    end

    if autoCompile and not target:isCompiled() then
        target:compile()
    end

    return true
end

local function isBuilding( ... )
    if type( currentRegistry ) == "table" or type( currentClass ) == "table" then
        if not ( currentRegistry and currentClass ) then
            throw("Failed to validate currently building class objects", "The 'currentClass' and 'currentRegistry' variables are not both set\n", "currentClass: "..tostring( currentClass ), "currentRegistry: "..tostring( currentRegistry ), ERROR_BUG)
        end
        return true
    end

    if #({ ... }) > 0 then
        return throw( ... )
    else
        return false
    end
end

local function getClass( target )
    if verifyClassEntry( target ) then
        return classes[ target ]
    elseif missingClassLoader then
        local oC, oCReg = currentClass, currentRegistry
        currentClass, currentRegistry = nil, nil

        missingClassLoader( target )
        local c = classes[ target ]
        if not verifyClassObject( c, true ) then
            throw("Failed to load missing class '"..target.."'.\n", "The missing class loader failed to load class '"..target.."'.\n")
        end

        currentClass, currentRegistry = oC, oCReg

        return c
    else throw("Class '"..target.."' not found") end
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

local function propertyCatch( tbl )
    if type( tbl ) == "table" then
        if tbl.static then
            if type( tbl.static ) ~= "table" then
                throw("Invalid entity found in trailing property table", "Expected type 'table' for entity 'static'. Found: "..tostring( tbl.static ), "\nThe 'static' entity is for storing static variables, refactor your class declaration.")
            end


            local cStatic, cOwnedStatics = currentRegistry.static, currentRegistry.ownedStatics
            for key, value in pairs( tbl.static ) do
                if reserved[ key ] then
                    throw(
                        "Failed to set static key '"..key.."' on building class '"..currentRegistry.type.."'",
                        "'"..key.."' is reserved by Titanium for internal processes."
                    )
                end

                cStatic[ key ] = value
                cOwnedStatics[ key ] = type( value ) == "nil" and nil or true
            end

            tbl.static = nil
        end

        local cKeys, cOwned = currentRegistry.keys, currentRegistry.ownedKeys
        for key, value in pairs( tbl ) do
            cKeys[ key ] = value
            cOwned[ key ] = type( value ) == "nil" and nil or true
        end
    elseif type( tbl ) ~= "nil" then
        throw("Invalid trailing entity caught\n", "An invalid object was caught trailing the class declaration for '"..currentRegistry.type.."'.\n", "Object: '"..tostring( tbl ).."' ("..type( tbl )..")".."\n", "Expected [tbl | nil]")
    end
end

local function createFunctionWrapper( fn, superLevel )
    return function( instance, ... )
        local oldSuper = instance:setSuper( superLevel )

        local v = { fn( ... ) }

        instance.super = oldSuper

        return unpack( v )
    end
end


--[[ Local Functions ]]--
local function compileSupers( targets )
    local inheritedKeys, superMatrix = {}, {}, {}
    local function compileSuper( target, id )
        local factories = {}
        local targetType = target.__type
        local targetReg = classRegistry[ targetType ]

        for key, value in pairs( targetReg.keys ) do
            if not reserved[ key ] then
                local toInsert = value
                if type( value ) == "function" then
                    factories[ key ] = function( instance, ... )
                        --print("Super factory for "..key.."\nArgs: "..( function( args ) local s = ""; for i = 1, #args do s = s .. " - " .. tostring( args[ i ] ) .. "\n" end return s end )( { ... } ))
                        local oldSuper = instance:setSuper( id + 1 )
                        local v = { value( instance, ... ) }

                        instance.super = oldSuper
                        return unpack( v )
                    end

                    toInsert = factories[ key ]
                end

                inheritedKeys[ key ] = toInsert
            end
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
                if not matrixReady and k == "super" then
                    upSuper = v
                    return
                end

                throw("Cannot set keys on super. Illegal action.")
            end
            function matrixMt:__index( k )
                factory = factories[ k ]
                if factory then
                    if not wrapCache[ k ] then
                        wrapCache[ k ] = (function( _, ... )
                            return factory( instance, ... )
                        end)
                    end

                    return wrapCache[ k ]
                else
                    if k == "super" then
                        return upSuper
                    else
                        return throw("Cannot lookup value for key '"..k.."' on super", "Only functions can be accessed from supers.")
                    end
                end
            end
            function matrixMt:__call( instance, ... )
                local init = self.__init__
                if type( init ) == "function" then
                    return init( self, ... )
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
local function mergeValues( a, b )
    if type( a ) == "table" and type( b ) == "table" then
        local merged = deepCopy( a ) or throw( "Invalid base table for merging." )

        if #b == 0 and next( b ) then
            for key, value in pairs( b ) do merged[ key ] = value end
        elseif #b > 0 then
            for i = 1, #b do table.insert( merged, i, b[ i ] ) end
        end

        return merged
    end

    return b == nil and a or b
end
local constructorTargets = { "orderedArguments", "requiredArguments", "argumentTypes", "useProxy" }
local function compileConstructor( superReg )
    local constructorConfiguration = {}

    local superConfig, currentConfig = superReg.constructor, currentRegistry.constructor
    if not currentConfig and superConfig then
        currentRegistry.constructor = superConfig
        return
    elseif currentConfig and not superConfig then
        superConfig = {}
    elseif not currentConfig and not superConfig then
        return
    end

    local constructorKey
    for i = 1, #constructorTargets do
        constructorKey = constructorTargets[ i ]
        if not ( ( constructorKey == "orderedArguments" and currentConfig.clearOrdered ) or ( constructorKey == "requiredArguments" and currentConfig.clearRequired ) ) then
            currentConfig[ constructorKey ] = mergeValues( superConfig[ constructorKey ], currentConfig[ constructorKey ] )
        end
    end
end
local function compileCurrent()
    isBuilding(
        "Cannot compile current class.",
        "No class is being built at time of call. Declare a class be invoking 'compileCurrent'"
    )
    local ownedKeys, ownedStatics, allMixins = currentRegistry.ownedKeys, currentRegistry.ownedStatics, currentRegistry.allMixins

    -- Mixins
    local cConstructor = currentRegistry.constructor
    for target in pairs( currentRegistry.mixins ) do
        allMixins[ target ] = true
        local reg = classRegistry[ target ]

        local t = { { reg.keys, currentRegistry.keys, ownedKeys }, { reg.static, currentRegistry.static, ownedStatics }, { reg.alias, currentRegistry.alias, currentRegistry.alias } }
        for i = 1, #t do
            local source, target, owned = t[ i ][ 1 ], t[ i ][ 2 ], t[ i ][ 3 ]
            for key, value in pairs( source ) do
                if not owned[ key ] then
                    target[ key ] = value
                end
            end
        end

        local constructor = reg.constructor
        if constructor then
            if constructor.clearOrdered then cConstructor.orderedArguments = nil end
            if constructor.clearRequired then cConstructor.requiredArguments = nil end

            local target
            for i = 1, #constructorTargets do
                target = constructorTargets[ i ]
                cConstructor[ target ] = mergeValues( cConstructor[ target ], constructor and constructor[ target ] )
            end

            cConstructor.tmlContent = cConstructor.tmlContent or constructor.tmlContent
        end
    end

    -- Supers
    local superKeys
    if currentRegistry.super then
        local supers = {}

        local last, c, newC = currentRegistry.super.target
        while last do
            c = getClass( last, true )

            supers[ #supers + 1 ] = c
            newC = classRegistry[ last ].super
            last = newC and newC.target or false
        end

        superKeys, currentRegistry.super.matrix = compileSupers( supers )

        -- Inherit alias from previous super
        local currentAlias = currentRegistry.alias
        for alias, redirect in pairs( classRegistry[ supers[ 1 ].__type ].alias ) do
            if currentAlias[ alias ] == nil then
                currentAlias[ alias ] = redirect
            end
        end

        for mName in pairs( classRegistry[ supers[ 1 ].__type ].allMixins ) do
            allMixins[ mName ] = true
        end

        compileConstructor( classRegistry[ supers[ 1 ].__type ] )
    end

    -- Generate instance function wrappers
    local instanceWrappers, instanceVariables = {}, {}
    for key, value in pairs( currentRegistry.keys ) do
        if type( value ) == "function" then
            instanceWrappers[ key ] = true
            instanceVariables[ key ] = createFunctionWrapper( value, 1 )
        else
            instanceVariables[ key ] = value
        end
    end
    if superKeys then
        for key, value in pairs( superKeys ) do
            if not instanceVariables[ key ] then
                if type( value ) == "function" then
                    instanceWrappers[ key ] = true
                    instanceVariables[ key ] = function( _, ... ) return value( ... ) end
                else
                    instanceVariables[ key ] = value
                end
            end
        end
    end

    -- Finish compilation
    currentRegistry.initialWrappers = instanceWrappers
    currentRegistry.initialKeys = instanceVariables
    currentRegistry.compiled = true

    currentRegistry = nil
    currentClass = nil

end
local function spawn( target, ... )
    if not verifyClassEntry( target ) then
        throw(
            "Failed to spawn class instance of '"..tostring( target ).."'",
            "A class entity named '"..tostring( target ).."' doesn't exist."
        )
    end

    local classEntry, classReg = classes[ target ], classRegistry[ target ]
    if classReg.abstract or not classReg.compiled then
        throw(
            "Failed to instantiate class '"..classReg.type.."'",
            "Class '"..classReg.type.."' "..(classReg.abstract and "is abstract. Cannot instantiate abstract class." or "has not been compiled. Cannot instantiate.")
        )
    end

    local wrappers, wrapperCache = deepCopy( classReg.initialWrappers ), {}
    local raw = deepCopy( classReg.initialKeys )
    local alias = classReg.alias

    local instanceID = string.sub( tostring( raw ), 8 )

    local supers = {}
    local function indexSupers( last, ID )
        while last.super do
            supers[ ID ] = last.super
            last = last.super
            ID = ID + 1
        end
    end

    local instanceObj, instanceMt = { raw = raw, __type = target, __instance = true, __ID = instanceID }, { __metatable = {} }
    local getting, useGetters, setting, useSetters = {}, true, {}, true
    function instanceMt:__index( k )
        local k = alias[ k ] or k

        local getFn = getters[ k ]
        if useGetters and not getting[ k ] and wrappers[ getFn ] then
            getting[ k ] = true
            local v = self[ getFn ]( self )
            getting[ k ] = nil

            return v
        elseif wrappers[ k ] then
            if not wrapperCache[ k ] then
                wrapperCache[ k ] = function( ... )
                    --print("Wrapper for "..k..". Arguments: "..( function( args ) local s = ""; for i = 1, #args do s = s .. " - " .. tostring( args[ i ] ) .. "\n" end return s end )( { ... } ) )
                    return raw[ k ]( self, ... )
                end
            end

            return wrapperCache[ k ]
        else return raw[ k ] end
    end

    function instanceMt:__newindex( k, v )
        local k = alias[ k ] or k

        local setFn = setters[ k ]
        if useSetters and not setting[ k ] and wrappers[ setFn ] then
            setting[ k ] = true
            self[ setFn ]( self, v )
            setting[ k ] = nil
        elseif type( v ) == "function" and useSetters then
            wrappers[ k ] = true
            raw[ k ] = createFunctionWrapper( v, 1 )
        else
            wrappers[ k ] = nil
            raw[ k ] = v
        end
    end

    function instanceMt:__tostring()
        return "[Instance] "..target.." ("..instanceID..")"
    end

    if classReg.super then
        instanceObj.super = classReg.super.matrix( instanceObj ).super
        indexSupers( instanceObj, 1 )
    end

    local old
    function instanceObj:setSuper( target )
        old, instanceObj.super = instanceObj.super, supers[ target ]
        return old
    end

    local function setSymKey( key, value )
        useSetters = false
        instanceObj[ key ] = value
        useSetters = true
    end

    local resolved
    local resolvedArguments = {}
    function instanceObj:resolve( ... )
        if resolved then return false end

        local args, config = { ... }, classReg.constructor
        if not config then
            throw("Failed to resolve "..tostring( instance ).." constructor arguments. No configuration has been set via 'configureConstructor'.")
        end

        local configRequired, configOrdered, configTypes, configProxy = config.requiredArguments, config.orderedArguments, config.argumentTypes or {}, config.useProxy or {}

        local argumentsRequired = {}
        if configRequired then
            local target = type( configRequired ) == "table" and configRequired or configOrdered

            for i = 1, #target do argumentsRequired[ target[ i ] ] = true end
        end

        local orderedMatrix = {}
        for i = 1, #configOrdered do orderedMatrix[ configOrdered[ i ] ] = i end

        local proxyAll, proxyMatrix = type( configProxy ) == "boolean" and configProxy, {}
        if not proxyAll then
            for i = 1, #configProxy do proxyMatrix[ configProxy[ i ] ] = true end
        end

        local function handleArgument( position, name, value )
            local desiredType = configTypes[ name ]
            if desiredType == "colour" or desiredType == "color" then
                --TODO: Check if number is valid (maybe?)
                desiredType = "number"
            end

            if desiredType and desiredType ~= "ANY" and type( value ) ~= desiredType then
                return throw("Failed to resolve '"..tostring( target ).."' constructor arguments. Invalid type for argument '"..name.."'. Type "..configTypes[ name ].." expected, "..type( value ).." was received.")
            end

            resolvedArguments[ name ], argumentsRequired[ name ] = true, nil
            if proxyAll or proxyMatrix[ name ] then
                self[ name ] = value
            else
                setSymKey( name, value )
            end
        end

        for iter, value in pairs( args ) do
            if configOrdered[ iter ] then
                handleArgument( iter, configOrdered[ iter ], value )
            elseif type( value ) == "table" then
                for key, v in pairs( value ) do
                    handleArgument( orderedMatrix[ key ], key, v )
                end
            else
                return throw("Failed to resolve '"..tostring( target ).."' constructor arguments. Invalid argument found at ordered position "..iter..".")
            end
        end

        if next( argumentsRequired ) then
            local str, name = ""
            local function append( cnt )
                str = str .."- "..cnt.."\n"
            end

            return throw("Failed to resolve '"..tostring( target ).."' constructor arguments. The following required arguments were not provided:\n\n"..(function()
                str = "Ordered:\n"
                for i = 1, #configOrdered do
                    name = configOrdered[ i ]
                    if argumentsRequired[ name ] then
                        append( name .. " [#"..i.."]" )
                        argumentsRequired[ name ] = nil
                    end
                end

                if next( argumentsRequired ) then
                    str = str .. "\nTrailing:\n"
                    for name, _ in pairs( argumentsRequired ) do append( name ) end
                end

                return str
            end)())
        end

        resolved = true
        return true
    end
    instanceObj.__resolved = resolvedArguments

    function instanceObj:can( method )
        return wrappers[ method ] or false
    end

    local locked = { __index = true, __newindex = true }
    function instanceObj:setMetaMethod( method, fn )
        if type( method ) ~= "string" then
            throw( "Failed to set metamethod '"..tostring( method ).."'", "Expected string for argument #1, got '"..tostring( method ).."' of type "..type( method ) )
        elseif type( fn ) ~= "function" then
            throw( "Failed to set metamethod '"..tostring( method ).."'", "Expected function for argument #2, got '"..tostring( fn ).."' of type "..type( fn ) )
        end

        method = "__"..method
        if locked[ method ] then
            throw( "Failed to set metamethod '"..tostring( method ).."'", "Metamethod locked" )
        end

        instanceMt[ method ] = fn
    end

    function instanceObj:lockMetaMethod( method )
        if type( method ) ~= "string" then
            throw( "Failed to lock metamethod '"..tostring( method ).."'", "Expected string, got '"..tostring( method ).."' of type "..type( method ) )
        end

        locked[ "__"..method ] = true
    end

    setmetatable( instanceObj, instanceMt )
    if type( instanceObj.__init__ ) == "function" then instanceObj:__init__( ... ) end

    for mName in pairs( classReg.allMixins ) do
        if type( instanceObj[ mName ] ) == "function" then instanceObj[ mName ]( instanceObj ) end
    end

    if type( instanceObj.__postInit__ ) == "function" then instanceObj:__postInit__( ... ) end

    return instanceObj
end


--[[ Global functions ]]--

function class( name )
    if isBuilding() then
        throw(
            "Failed to declare class '"..tostring( name ).."'",
            "A new class cannot be declared until the currently building class has been compiled.",
            "\nCompile '"..tostring( currentRegistry.type ).."' before declaring '"..tostring( name ).."'"
        )
    end

    local function nameErr( reason )
        throw( "Failed to declare class '"..tostring( name ).."'\n", string.format( "Class name %s is not valid. %s", tostring( name ), reason ) )
    end

    if type( name ) ~= "string" then
        nameErr "Class names must be a string"
    elseif not name:find "%a" then
        nameErr "No alphabetic characters could be found"
    elseif name:find "%d" then
        nameErr "Class names cannot contain digits"
    elseif classes[ name ] then
        nameErr "A class with that name already exists"
    elseif reserved[ name ] then
        nameErr ("'"..name.."' is reserved for Titanium processes")
    else
        local char = name:sub( 1, 1 )
        if char ~= char:upper() then
            nameErr "Class names must begin with an uppercase character"
        end
    end

    local classReg = {
        type = name,

        static = {},
        keys = {},
        ownedStatics = {},
        ownedKeys = {},

        initialWrappers = {},
        initialKeys = {},

        mixins = {},
        allMixins = {},
        alias = {},

        constructor = {},
        super = false,

        compiled = false,
        abstract = false
    }

    -- Class metatable
    local classMt = { __metatable = {} }
    function classMt:__tostring()
        return (classReg.compiled and "[Compiled] " or "") .. "Class '"..name.."'"
    end

    local keys, owned = classReg.keys, classReg.ownedKeys
    local staticKeys, staticOwned = classReg.static, classReg.ownedStatics
    function classMt:__newindex( k, v )
        if classReg.compiled then
            throw(
                "Failed to set key on class base.", "",
                "This class base is compiled, once a class base is compiled new keys cannot be added to it",
                "\nPerhaps you meant to set the static key '"..name..".static."..k.."' instead."
            )
        end

        keys[ k ] = v
        owned[ k ] = type( v ) == "nil" and nil or true
    end
    function classMt:__index( k )
        if owned[ k ] then
            throw (
                "Access to key '"..k.."' denied.",
                "Instance keys cannot be accessed from a class base, regardless of compiled state",
                classReg.ownedStatics[ k ] and "\nPerhaps you meant to access the static variable '" .. name .. ".static.".. k .. "' instead" or nil
            )
        elseif staticOwned[ k ] then
            return staticKeys[ k ]
        end
    end
    function classMt:__call( ... )
        return spawn( name, ... )
    end

    -- Static metatable
    local staticMt = { __index = staticKeys }
    function staticMt:__newindex( k, v )
        staticKeys[ k ] = v
        staticOwned[ k ] = type( v ) == "nil" and nil or true
    end

    -- Class object
    local classObj = { __type = name }
    classObj.static = setmetatable( {}, staticMt )
    classObj.compile = compileCurrent

    function classObj:isCompiled() return classReg.compiled end

    function classObj:getRegistry() return classReg end

    setmetatable( classObj, classMt )

    -- Export
    currentRegistry = classReg
    classRegistry[ name ] = classReg

    currentClass = classObj
    classes[ name ] = classObj

    _G[ name ] = classObj

    return propertyCatch
end

function extends( name )
    isBuilding(
        string.format( ERROR_GLOBAL, "extend", "target class '"..tostring( name ).."'" ), "",
        string.format( ERROR_NOT_BUILDING, "extends" )
    )

    currentRegistry.super = {
        target = name
    }
    return propertyCatch
end

function mixin( name )
    if type( name ) ~= "string" then
        throw("Invalid mixin target '"..tostring( name ).."'")
    end

    isBuilding(
        string.format( ERROR_GLOBAL, "mixin", "target class '".. name .."'" ),
        string.format( ERROR_NOT_BUILDING, "mixin" )
    )

    local mixins = currentRegistry.mixins
    if mixins[ name ] then
        throw(
            string.format( ERROR_GLOBAL, "mixin class '".. name .."'", "class '"..currentRegistry.type)
            "'".. name .."' has already been mixed in to this target class."
        )
    end

    if not getClass( name, true ) then
        throw(
            string.format( ERROR_GLOBAL, "mixin class '".. name .."'", "class '"..currentRegistry.type ),
            "The mixin class '".. name .."' failed to load"
        )
    end

    mixins[ name ] = true
    return propertyCatch
end

function abstract()
    isBuilding(
        "Failed to enforce abstract class policy\n",
        string.format( ERROR_NOT_BUILDING, "abstract" )
    )

    currentRegistry.abstract = true
    return propertyCatch
end

function alias( target )
    local FAIL_MSG = "Failed to implement alias targets\n"
    isBuilding( FAIL_MSG, string.format( ERROR_NOT_BUILDING, "alias" ) )

    local tbl = type( target ) == "table" and target or (
        type( target ) == "string" and (
            type( _G[ target ] ) == "table" and _G[ target ] or throw( FAIL_MSG, "Failed to find '"..tostring( target ).."' table in global environment." )
        ) or throw( FAIL_MSG, "Expected type table as target, got '"..tostring( target ).."' of type "..type( target ) )
    )

    local cAlias = currentRegistry.alias
    for alias, redirect in pairs( tbl ) do
        cAlias[ alias ] = redirect
    end

    return propertyCatch
end

function configureConstructor( config, clearOrdered, clearRequired )
    isBuilding(
        "Failed to configure class constructor\n",
        string.format( ERROR_NOT_BUILDING, "configureConstructor" )
    )

    if type( config ) ~= "table" then
        throw (
            "Failed to configure class constructor\n",
            "Expected type 'table' as first argument"
        )
    end

    local constructor = {
        clearOrdered = clearOrdered or nil,
        clearRequired = clearRequired or nil
    }
    for key, value in pairs( config ) do constructor[ key ] = value end

    currentRegistry.constructor = constructor
    return propertyCatch
end

--[[ Class Library ]]--
Titanium = {}

function Titanium.getGetterName( property ) return getters[ property ] end

function Titanium.getSetterName( property ) return setters[ property ] end

function Titanium.getClass( name )
    return classes[ name ]
end

function Titanium.getClasses()
    return classes
end

function Titanium.isClass( target )
    return type( target ) == "table" and type( target.__type ) == "string" and verifyClassEntry( target.__type )
end

function Titanium.isInstance( target )
    return Titanium.isClass( target ) and target.__instance
end

function Titanium.typeOf( target, classType, instance )
    if not Titanium.isClass( target ) or ( instance and not Titanium.isInstance( target ) ) then
        return false
    end

    local targetReg = classRegistry[ target.__type ]

    return targetReg.type == classType or ( targetReg.super and Titanium.typeOf( classes[ targetReg.super.target ], classType ) ) or false
end

function Titanium.mixesIn( target, mixinName )
    if not Titanium.isClass( target ) then return false end

    return classRegistry[ target.__type ].allMixins[ mixinName ]
end

function Titanium.setClassLoader( fn )
    if type( fn ) ~= "function" then
        throw( "Failed to set class loader", "Value '"..tostring( fn ).."' is invalid, expected function" )
    end

    missingClassLoader = fn
end

local preprocessTargets = {"class", "extends", "alias", "mixin"}
function Titanium.preprocess( text )
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
