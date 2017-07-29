--[[
    Load an example TML file and perform various operations on the result to determine it's success
]]

runTask("TML_PARSE", function()
    TML( TestApplication, [[
        <Button text="Hello World"/>

        <Container X=2 Y=5 height=10 width=40>
            <ScrollContainer X=2>
                <Label text="Test"/>
            </ScrollContainer>
        </Container>

        <Container id="wrapper">
            <ScrollContainer class="test" id="cont">
                <Container id="inner">
                    <Button class="butt" id="confirm" text="CI"/>
                </Container>
            </ScrollContainer>
        </Container>
    ]])

    return true
end)

runTask("COLLATED_NODES_COUNT", function()
    local collated = TestApplication.collatedNodes
    return #collated == 8 or #collated
end)

runTask("TML_STRING_ASSIGN", function()
    local button = TestApplication:query "Button".result[1]
    if not button then
        return "Query failed. 'Button' result 1 not found"
    end

    return button.text == "Hello World" or button.text
end)

local scroller = TestApplication:query "ScrollContainer".result[1]
if not scroller then
    return error "Query failed. 'ScrollContainer' result 1 not found"
end

runTask("TML_NUMBER_ASSIGN", function()
    return scroller.X == 2 or scroller.X
end)

runTask("TML_QUERY_SIMPLE", function()
    local res = #NodeQuery( TestApplication, "#wrapper .test Button#confirm" ).result
    return res == 1 or res
end)

runTask("TML_QUERY_COMPLEX", function()
    local res = #NodeQuery( TestApplication, "Container#wrapper > ScrollContainer.test#cont Button#confirm.butt" ).result
    return res == 1 or res
end)

runTask("TML_QUERY_ADVANCED", function()
    local res = #NodeQuery( TestApplication, "Container#wrapper > ScrollContainer.test#cont > Container#inner > .butt" ).result
    return res == 1 or res
end)

runTask("TML_QUERY_INVERSE", function()
    local res = #NodeQuery( TestApplication, "Container#wrapper > ScrollContainer.test#cont > .someRandomClass" ).result
    return res == 0 or res
end)
