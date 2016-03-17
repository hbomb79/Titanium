-- Functions that are used as helpers by classes (not the class system)

function _G.parseClassArguments( instance, arguments, orderedArguments, requiredArguments, returnOrderedArguments, argumentTypes )
	if instance.__constructed then return error("Failed to parse class arguments, this instance has already been constructed") end

	if requiredArguments == true then requiredArguments = orderedArguments end

	if type( requiredArguments ) == "table" and #arguments < #requiredArguments then
		return error("Failed to parse class arguments, class requires the following arguments at construction: "..tostring( textutils.serialise( requiredArguments ) ) )
	elseif #arguments > #orderedArguments + 1 then -- too many, only one extra argument can be passed (parse table)
		return error("Failed to parse class arguments, class doesn't accept "..tostring( #arguments ).." arguments (including parse table)")
	end

	local argsToDefine = {}
	for i = 1, #requiredArguments do
		argsToDefine[ requiredArguments[ i ] ] = true
	end

	local returnArgs, arg = {}
	for i = 1, #arguments do
		arg = arguments[ i ]
		if orderedArguments[ i ] then
			local argType = argumentTypes[ orderedArguments[ i ] ]
			if argType and type( arg ) ~= argType then
				return error("Class expected argument '"..orderedArguments[ i ].."' at position '"..i.."' to be type '"..argType.."', got '"..type( arg ).."' instead.")	
			end

			if returnOrderedArguments then
				returnArgs[ i ] = arg
			else
				instance[ orderedArguments[ i ] ] = arg
			end

			argsToDefine[ orderedArguments[ i ] ] = nil
		else
			if type( arg ) == "table" then
				local orderedArgs = {}
				for i = 1, #orderedArguments do
					orderedArgs[ orderedArguments[ i ] ] = i
				end

				for parse, value in pairs( arg ) do
					local argType = argumentTypes[ parse ]
					if argType and type( value ) ~= argType then
						return error("Class expected argument '"..parse.."' as type '"..argType.."' inside of parse table (last argument). Got type '"..type( value ).."' instead" )
					end

					-- set the argument unless the argument is also an ordered argument, in which case replace the old one with this one
					if returnOrderedArguments and orderedArgs[ parse ] then
						-- this is a re-definition of an ordered argument that the constructor wants back
						returnArgs[ orderedArgs[ parse ] ] = value
					else	
						instance[ parse ] = value
					end

					argsToDefine[ parse ] = nil
				end
			else
				return error("Trailing argument of type '"..type( arg ).."' cannot be parsed")
			end
		end
	end

	if next( argsToDefine ) then
		error("Required arguments not complete, the following arguments are required: "..textutils.serialise( argsToDefine ))
	end

	if returnOrderedArguments then return unpack( returnArgs ) end
end
