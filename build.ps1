$jdk=$Env:JAVA_HOME

if ((Get-Command "mvn" -ErrorAction SilentlyContinue) -eq $null)
{
   Write-Error "Unable to find mvn.cmd in your PATH (try: choco install maven)"
   exit 1
}
if ((Get-Command 'wix' -ErrorAction SilentlyContinue) -eq $null)
{
   Write-Error 'Unable to find wix in your PATH (try: dotnet tool install --global wix --version 6.0.0)'
   exit 1
}
$wixExtensions = & wix.exe extension list --global | Out-String
if ($wixExtensions -notmatch 'WixToolset.UI.wixext') {
    Write-Error 'Wix UI extension missing. Please install it with: wix.exe extension add WixToolset.UI.wixext/6.0.0 --global)'
    exit 1
}
if ($wixExtensions -notmatch 'WixToolset.Util.wixext') {
    Write-Error 'Wix Util extension missing. Please install it with: wix.exe extension add WixToolset.Util.wixext/6.0.0 --global)'
    exit 1
}

$buildDir = Split-Path -Parent $PSCommandPath
& $buildDir\mvnw.cmd -B -f $buildDir/pom.xml clean verify -DskipTests
New-Item -ItemType Directory -Path "$buildDir\target\mods"
Copy-Item "$buildDir\target\jpackage-arm-bug-*.jar" -Destination "$buildDir\target\mods"

## create runtime
### check for JEP 493
$jmodPaths=@()
if ((& "$jdk\bin\jlink" --help | Select-String -Pattern "Linking from run-time image enabled" -SimpleMatch | Measure-Object).Count -eq 0 ) {
	$jmodPaths=@("--module-path", "$jdk/jmods");
}

### create runtime
& "$jdk\bin\jlink" `
	--verbose `
	--output target/runtime `
	--strip-native-commands `
	--no-header-files `
	--no-man-pages `
	--strip-debug `
	--add-modules java.base `
    @jmodPaths

# create msi
$uuid=$(New-Guid).Guid
& "$jdk\bin\jpackage" `
	--verbose `
	--type msi `
	--runtime-image target/runtime `
    --module-path target/mods `
    --module org.example.jpackageArmBug/org.example.App `
	--win-upgrade-uuid "$uuid" `
	--dest target/installer `
	--name ExampleApp `
	--vendor ExampleVendor `
	--copyright 2025 `
	--app-version "1.0.0"