echo "Starting build"
lua bin/construct.lua -s src -m -o build/titanium.min.lua
echo "Minified build complete (build/titanium.min.lua)"
lua bin/construct.lua -s src -o build/titanium.lua
echo "Done"
