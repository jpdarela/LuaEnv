# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

## Remove downloads folder
$downloadsPath = Join-Path $ScriptDir "downloads"
if (Test-Path $downloadsPath) {
    Write-Host "Removing downloads folder: $downloadsPath"
    Remove-Item -Path $downloadsPath -Recurse -Force
} else {
    Write-Host "No downloads folder found at: $downloadsPath"
}

## Remove build folder
$buildPath = Join-Path $ScriptDir "lua-5.4.8"
if (Test-Path $buildPath) {
    Write-Host "Removing build folder: $buildPath"
    Remove-Item -Path $buildPath -Recurse -Force
} else {
    Write-Host "No build folder found at: $buildPath"
}

## Remove luarocks folder
$luarocksPath = Join-Path $ScriptDir "luarocks-3.12.2-windows-64"
if (Test-Path $luarocksPath) {
    Write-Host "Removing luarocks folder: $luarocksPath"
    Remove-Item -Path $luarocksPath -Recurse -Force
} else {
    Write-Host "No luarocks folder found at: $luarocksPath"
}

## remove the .lua_prefix.txt file if it exists
$prefixFilePath = Join-Path $ScriptDir ".lua_prefix.txt"
if (Test-Path $prefixFilePath) {
    Write-Host "Removing prefix file: $prefixFilePath"
    Remove-Item -Path $prefixFilePath -Force
} else {
    Write-Host "No prefix file found at: $prefixFilePath"
}

Write-Host "Cleanup completed."
