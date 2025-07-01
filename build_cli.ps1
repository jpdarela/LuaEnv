# Build CLI project and publish to ./publish directory
# Ensure you have the .NET SDK installed and available in your PATH
# This script assumes you are running it from the root of the LuaEnv project
& dotnet publish cli/LuaEnv.CLI -c Release -o ./publish `
  --self-contained false `
  -p:PublishSingleFile=false `
  -p:IncludeNativeLibrariesForSelfExtract=true `
  -p:SatelliteResourceLanguages=en
