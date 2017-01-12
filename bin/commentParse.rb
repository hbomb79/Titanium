## NOTICE ##
# This is my first time using Ruby, apologies if your eyes hurt

# Require the JSON gem, used when exporting the function data.
require "json"

# A simple Ruby script that finds (Lua) block comments above class
# methods inside of Titanium .ti (class) files.

# The comments are gathered, stored and saved at the given output
# path in JSON format.

##
# This function simply returns true if the path provided is a directory.
#
# If the path doesn't exist, or is a file, false will be returned.
def isDirectory( path )
    # Using the File class (directory? method), determine if the path
    # is a directory and return this value
    return File.directory? path
end

##
# Given a path, returns the name of the file (ie: the last segement of the path) without the file extension
#
# If the path has no segments (ie: Path.lua), the file extension will be removed (if present) and the remaining
# string returned. If no file extension, 'path' will be returned
#
# If the path has segments (ie: src/classes/Path.lua), the last segment will be used, and the above will
# apply. If a file extension is present it will automatically be removed.
def getFileName( path )
    re = path.match(/(\/?[[^\/]+\/]+)?\/(\w*)(\.\w+$)?/)
    if re.nil?
        # No match, the file path must be the name as well. Try and remove
        # a file extension, if one is present
        if File.extname( path ).empty?
            # No file extension, file path IS the name
            return path
        else
            extMatch = path.match(/(\w+)\./)
            if extMatch.nil?
                raise "Failed to find file name of #{path}. Detected file extension, but could not parse"
            else
                # Return the content of the first capture (the file name, with extension removed)
                return extMatch.captures[ 0 ]
            end
        end
    else
        # We matched, return the file name (2nd capture, array[1])
        return re.captures[ 1 ]
    end
end


##
# This function explores the 'target' path and creates a list
# of file paths inside of 'target'.
#
# Target is searched recursively, hence files inside sub-directories
# will also be included.
def exploreFiles( target, results = Array[] )
    # First, check if the target is a directory
    if isDirectory( target )
        # Okay, target is a directory, get all the entries inside the
        # directory and iterate over them
        Dir.entries( target ).each do |path|
            fullPath = "#{target}/#{path}"
            # We are now iterating over each of the directory entries. Ignore
            # paths that do NOT end with .ti, they are not Titanium class files
            # and we do not want to create documentation for them.

            # However, if a path is a directory, iterate over that too
            if path != "." and path != ".."
                if isDirectory fullPath
                    results = exploreFiles( fullPath, results )
                elsif File.extname( path ) == ".ti"
                    # Alright! The path is marked as a Titanium class file via the .ti ext.
                    # Lets begin parsing for functions and comments.
                    results.push fullPath
                end
            end
        end

        return results
    else
        raise "Failed to generate documentation. Cannot explore #{target}, is a file"
    end
end

# Okay, grab all the Titanium source files
files = exploreFiles "src"

if files.empty?
    raise "Cannot generate documentation. No files found while exploring 'src'. Bailing out!"
end

puts "<<Discovering functions>>\n\n"
foundFunctions = {}
categories = {
    "core" => "core",
    "event" => "core",
    "graphics" => "core",
    "nodes" => "nodes",
    "utils" => "util",
    "mixins" => "mixins"
}
files.each do |path|
    # Open this file and get it's content.
    content = File.read( path )
    puts "Parsing #{path} for documented functions"

    # Find the block comment above the class declaration
    filename = getFileName( path )

    if foundFunctions[ filename ].nil?
        foundFunctions[ filename ] = { "functionComments" => {}, "path" => path, "mixins" => [], "category" => ( categories[ getFileName( File.expand_path( "..", path ) ) ] || categories[ getFileName( File.expand_path( "../..", path ) ) ] || "unknown" ) }
    end

    docMatch = content.match(/.*\-*?\[\[(.*?)\-*?\]\].+class #{filename}/m)
    if docMatch.nil?
        puts "Failed to find class file comment for #{filename}"
    else
        # We found the comment
        puts "Found class block comment for #{path}"
        foundFunctions[ filename ][ "comment" ] = docMatch.captures[ 0 ]
    end

    ##
    # Search the class declaration for 'extends <Class>', 'mixin <class>', and the 'abstract' keyword.
    # Firstly, is the class abstract. To determine, it will have 'abstract' before the 'class' keyword
    abstract = content.match(/abstract\s*class\s*["']?#{filename}["']?/)
    if !abstract.nil?
        puts "Class #{filename} is abstract"
        foundFunctions[ filename ][ "abstract" ] = true
    else
        puts "Failed to find 'abstract' keyword - class #{filename} is not abstract"
    end

    # Next, what class does it extend
    extension = content.match(/class\s*["']?#{filename}["']?.*extends\s*['"]?(\w*)['"]?/)
    if !extension.nil?
        puts "Found class extension for #{filename}. Extends #{extension.captures[ 0 ]}"
        foundFunctions[ filename ][ "extends" ] = extension.captures[ 0 ]
    else
        puts "Failed to find class extension for #{filename}"
    end

    # Now, find all the mixins of this class.
    declaration = content.match(/class\s*["']?#{filename}["']?(.*)$/)
    if !declaration.nil?
        mixins = foundFunctions[ filename ][ "mixins" ]
        decl = declaration.captures[ 0 ]
        decl.scan (/mixin\s*(\w*)\s*/) {|w| mixins.push( w[0] ) }

        if mixins.length > 0
            puts("Found mixin#{mixins.length > 1 ? "s" : ""} #{mixins.join( ", " )} for #{filename}")
        end
    end

    # To find all functions (and their comment), we wil use regex. This regex uses two captures,
    # the first being the comment, and the second being the function definition (containing the)
    # function name, and it's arguments.
    while true
        # Okay, iterate over the string until the regex no longer matches
        matched = content.match(/.+\-{2,}\[\[(.*)\-*\]\]\s*?(function #{filename}:\w+\(.*?\))/m)
        if matched.nil?
            # No match found, bail out - we are done with this file
            puts "File #{filename} parsed - no more matches found\n\n"
            break
        else
            # Alright, our regex matched. Our first capture (array[0]) contains
            # the comment for the function stored in the second capture (array[1]).
            captures = matched.captures
            puts "Found function #{captures[ 1 ]}"


            foundFunctions[ filename ][ "functionComments" ][ captures[ 1 ] ] = captures[ 0 ] # Store the comment (value) under the function (key) inside the hash structure.

            # Okay, now that we matched this, we need to remove it from the string. If we don't
            # it will be matched indefinitely by our while loop.

            # Remove the function line - that will stop the regex from matching
            # the comment above it as well.
            content = content.gsub( captures[ 1 ], "" )
        end
    end
end


# We have parsed all source files for documented functions, now we must parse the comments
# into valuable information. For example, finding all the parameters or return values.
#
# To do this, we will read the comment line by line. Depending on the type of the line (dictated)
# using '@', the line will be parsed to gather information.

outDocs = {}
functionTotal = 0
puts "\n<<Parsing discovered functions>>\n\n"
foundFunctions.each do |filename, info|
    # We are now iterating over the information we found from each file, which is
    # the file comment, and each function/comment combination.

    # First, create an output hash for us to use
    outDocs[ filename ] = {
        "category" => info["category"],
        "path" => info["path"],
        "abstract" => info["abstract"] || false,
        "mixins" => info["mixins"],
        "extends" => info["extends"],
        "parameters" => {
            "static" => {},
            "instance" => {}
        },
        "functions" => {
            "static" => [],
            "instance" => []
        }
    }

    # Now, parse the file comment if there is one
    if not info["comment"].nil?
        # A comment was defined, lets parse it. To do so, iterate over each line
        lines = info["comment"].split "\n"
        docs = ""
        lines.each do |line|
            # Check if this line follows the format: @(instance|static) propertyName - propertyType(s) (def. defaultValue) - desc
            # Example @instance running - boolean, nil (def. false) - A description
            # Another: @static easing - table (def. false) - A description

            matched = line.match(/@(instance|static)\s+(\w+)\s*\-\s*([\w\s,]+)\s*\(def.\s*(.*?)\)\s*\-\s*(.*)/)
            if !matched.nil?
                # A correctly formatted property comment was found, handle the captured information
                captures = matched.captures
                outDocs[ filename ][ "parameters" ][ captures[ 0 ] ][ captures[ 1 ] ] = {
                    "types" => captures[ 2 ].split(","),
                    "default" => captures[ 3 ],
                    "desc" => captures[ 4 ]
                }
            else
                docs = docs + "\n" + line
            end
        end

        outDocs[ filename ][ "desc" ] = docs
    end

    # Next, parse each function comment
    # To do this, we must find @instance|static, @param, @desc and @return lines.
    # @param and @return lines are split on ',', others are left as is.
    info["functionComments"].each do |functionDef, functionComment|
        # Split the comment into lines
        lines = functionComment.split "\n"
        if lines[ 1 ].nil?
            puts "Foreign comment found above instance function. Ignoring"
            next
        end

        # Is this a instance or static function?
        type = lines[ 1 ].match(/^\s*@(instance|static|constructor|getter|setter)/)
        if type.nil?
            puts "Unknown type for function #{functionDef}, with documentation comment #{functionComment}. Ignoring"
            next
        end

        type = type.captures[ 0 ]

        # What is this functions name?
        functionName = functionDef.match( /function #{filename}:(\w+)\(.*\)/ )
        if functionName.nil?
            raise "Failed to generate documentation. Couldn't part function name out of input '#{functionDef}'"
        end

        functionName = functionName.captures[ 0 ]

        # What is it's description
        functionDescription = functionComment.match( /@desc (.*?)(\z|@param|@return)/m )
        if functionDescription.nil?
            functionDescription = false
        else
            functionDescription = functionDescription.captures[ 0 ]
        end

        # What parameters does it accept?
        # Function comments can define multiple sets of parameters. To handle this, we will use
        # iteration. The same applies to @return lines, so we'll handle those here too.
        functionParameters, functionReturns = Array[], Array[]
        lines.each do |line|
            lineMatch = line.match(/^\s*@(\w*)(.*?)$/)
            if !lineMatch.nil?
                lineType = lineMatch.captures[ 0 ]
                lineParts = lineMatch.captures[ 1 ]
                if lineType == "return" or lineType == "param"
                    # To find the two parts of this, we will split the string, splitting the variables and description
                    # into two seperate captures.
                    descSplit = lineParts.match(/((.+[>\]])\s*\-\s*(.+)|.+)$/)
                    if !descSplit.nil?
                        # Okay, we got the description and variables split. Now, we will
                        # split each variable up and parse it for the variable information
                        # we want
                        caps = descSplit.captures
                        store = {
                            "description" => caps[ 2 ].nil? ? "No description" : caps[ 2 ],
                            "arguments" => []
                        }

                        (caps[ 1 ].nil? ? caps[ 0 ] : caps[ 1 ]).split(/,\s*/).each do |var|
                            # Each iteration is another variable, parse it
                            # Get the opening and closing bracket
                            # Get the first and second segment

                            parts = var.match(/\s*([<\[])\s*(.*?)\s*\-\s*(.*?)\s*([>\]])/)
                            if !parts.nil?
                                opening, closing = parts.captures[ 0 ], parts.captures[ -1 ]
                                if ( opening == "<" and closing != ">" ) or ( opening == "[" and closing != "]" )
                                    raise "Unbalanced variable comment - lingering bracket in '#{var}'"
                                elsif (opening != "<" and opening != "[") or (closing != ">" and closing != "]")
                                    raise "Unknown bracket inside variable comment. Open '#{parts.captures[ 0 ]}'"
                                end
                                    

                                # The brackets match, this variable can be pushed
                                puts("Found argument #{parts.captures[2]} (type #{parts.captures[ 1 ]}#{parts.captures[0] == "[" ? ", optional" : ""}) for #{filename}:#{functionName}")
                                store["arguments"].push({
                                    "name" => parts.captures[ 2 ],
                                    "type" => parts.captures[ 1 ],
                                    "optional" => parts.captures[ 0 ] == "["
                                })
                            end
                        end

                        # Push the store into the main stack
                        if lineType == "return"
                            functionReturns.push store
                        else
                            functionParameters.push store
                        end
                    end
                end
            end
        end

        ##
        # *wipes brow* We have parsed all the param and result lines, and found the
        # function name, type, and description. Now we can finally push all this
        # information
        outDocs[ filename ]["functions"][ ( type == "constructor" or type == "setter" or type == "getter" ) ? "instance" : type ].push({
            "name" => functionName,
            "desc" => functionDescription,
            "parameters" => functionParameters,
            "returns" => functionReturns,
            "isConstructor" => type == "constructor",
            "isSetter" => type == "setter",
            "isGetter" => type == "getter"
        })

        puts "Done parsing function #{functionName}\n"
        functionTotal+=1
    end
end

puts "\n\n<<Success - Parsed #{functionTotal} functions over #{outDocs.length} files>>"
File.write("rubyout", JSON.generate( outDocs ) )