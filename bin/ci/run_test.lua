--[[
    Test Titanium build files using various tests

    This is mainly used for CI testing
]]

print "Beginning build test"

local tests = { tml = {} }
local activeTest, activeTask, buildLocation

-- Local functions
local function throw( message, level )
    error([[Failed to test build ']]..tostring( buildLocation )..[['
Active test: ]] .. ( activeTest or "No active test" ) .. [[

Active task: ]] .. ( activeTask or "No active task" ) .. [[


Error: ]] .. message .. [[
]] , level and level + 1 or 2 )
end

local function runTask( name, fn )
    activeTask = name
    local status = fn()

    if status == true then
        print( name .. ": OK" )
    else
        return error( status )
    end

    activeTask = nil
end

local function resolveDependencies( testName )
    print("Resolving '"..testName.."' dependencies")
    local config = tests[ testName ]
    if not config then return end

    local dep = config.dependencies or {}
    for i = 1, #dep do
        print( dep[ i ] .. " depended upon by '"..testName.."'")
        runTest( testName, true )
    end
end

local loaded, ENV = {}, setmetatable({ runTask = runTask }, { __index = _G })
local function runTest( testName, isDependency )
    if loaded[ testName ] then return end
    loaded[ testName ] = true

    print("Running test '"..testName.."'" .. ( isDependency and " as dependency" or "" ))

    local path = "/bin/ci/tests/" .. testName .. ".lua"
    if not fs.exists( path ) or fs.isDir( path ) then
        throw( "Failed to execute test '"..testName.."'. Path '"..tostring( path ).."' " .. ( fs.isDir( path ) and "is a directory" or "not found" ) )
    end

    print("Test path '"..path.."': OK")
    resolveDependencies( testName )

    print("Execute test '"..testName.."'")
    activeTest = testName

    local fn, err = loadfile( path, ENV )
    if fn then
        local ok, err = pcall( fn )
        if not ok then throw( err ) end
    else
        throw("Failed to loadfile '"..tostring( path ).."'")
    end
end

-- Validate argument count
local args = { ... }
if #args < 2 then
    throw "Invalid arguments passed. Expected location of Titanium build file and tests to run"
end
print "Arguments tested: OK"

if not ( type( _HOST ) == "string" and _HOST:find "ComputerCraft" ) then
    throw "Tests must be executed inside of the ComputerCraft environment. This file has been executed outside of the CC env and cannot operate"
end
print "Host checked: OK"

-- Fetch build location
buildLocation = args[ 1 ] or throw("Invalid build location '"..tostring( buildLocation ).."'")
if not fs.exists( buildLocation ) or fs.isDir( buildLocation ) then
    throw( "Failed to load Titanium build. Path '"..tostring( buildLocation ).."' " .. ( fs.isDir( buildLocation ) and "is a directory" or "not found" ) )
end

-- Load Titanium, validate load complete
dofile( buildLocation )
if not _G.Titanium then
    throw "Titanium failed to load into the global environment"
end
print "Build loaded: OK"

-- Setup ENV with `TestApplication`
local ok, err = pcall( function() ENV.TestApplication = Application() end )
if not ok then
    throw("Failed to setup environment: " .. tostring( err ))
end

-- Run tasks
for test = 2, #args do
    runTest( args[ test ] )
end
