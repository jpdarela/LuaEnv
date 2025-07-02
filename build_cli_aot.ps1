# Build CLI project with Native AOT for maximum startup performance
# This creates a larger executable but eliminates JIT compilation delays
# Requires additional setup for JSON serialization compatibility

# First, check if we need the Microsoft.NETCore.Native.targets
Write-Host "Building CLI with Native AOT compilation..."
Write-Host "Note: This creates a larger executable but faster startup"
Write-Host ""

# Build with Native AOT and required trimming
& dotnet publish cli/LuaEnv.CLI -c Release -o ./publish_aot `
  --self-contained true `
  -p:PublishAot=true `
  -p:PublishTrimmed=true `
  -p:TrimMode=link `
  -p:PublishSingleFile=false `
  -p:InvariantGlobalization=true `
  -p:SuppressTrimAnalysisWarnings=true

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "AOT build completed successfully!"
    Write-Host "Output: ./publish_aot/"
    Write-Host ""
    Write-Host "To deploy AOT version:"
    Write-Host "  python install.py --cli --force --source ./publish_aot"
} else {
    Write-Host ""
    Write-Host "AOT build failed. This is expected if JSON serialization needs fixes."
    Write-Host "Use the regular build_cli.ps1 for standard JIT compilation."
}
