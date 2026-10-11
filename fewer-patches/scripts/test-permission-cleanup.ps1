param(
    [Parameter(Mandatory)][string]$OriginalJar,
    [Parameter(Mandatory)][string]$DependencyDirectory,
    [Parameter(Mandatory)][string]$PaperLibraryDirectory,
    [string]$JavaHome = 'C:\Program Files\Java\jdk-25.0.2'
)
$ErrorActionPreference = 'Stop'
$patchRoot = Split-Path $PSScriptRoot
$projectRoot = Split-Path $patchRoot
$buildRoot = Join-Path $projectRoot 'build'
$testClasses = Join-Path $buildRoot 'test-classes'
# Optional API signature for mocking FusionPaper only; never included in the plugin jar.
$stub = Join-Path $buildRoot 'test-support/me/arcaniax/hdb/api/HeadDatabaseAPI.java'
New-Item -ItemType Directory -Force (Split-Path $stub) | Out-Null
[IO.File]::WriteAllText($stub, 'package me.arcaniax.hdb.api; public class HeadDatabaseAPI {}')
$dependencies = Get-ChildItem $DependencyDirectory,$PaperLibraryDirectory -Recurse -Filter '*.jar' -File | Select-Object -ExpandProperty FullName
$classpath = (@("$buildRoot/classes", $OriginalJar) + $dependencies) -join ';'
& "$JavaHome/bin/javac.exe" -cp $classpath -d $testClasses $stub (Join-Path $patchRoot 'PermissionCleanupRegression.java')
if ($LASTEXITCODE) { throw 'Permission regression compilation failed' }
$mockitoAgent = Get-ChildItem $DependencyDirectory -Filter 'mockito-core-*.jar' | Select-Object -First 1 -ExpandProperty FullName
& "$JavaHome/bin/java.exe" "-javaagent:$mockitoAgent" '-Dnet.bytebuddy.experimental=true' -cp "$testClasses;$classpath" PermissionCleanupRegression
if ($LASTEXITCODE) { throw 'Permission regression failed' }
