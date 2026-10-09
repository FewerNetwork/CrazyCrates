param(
    [Parameter(Mandatory)][string]$OriginalJar,
    [Parameter(Mandatory)][string]$DependencyDirectory,
    [string]$JavaHome = 'C:\Program Files\Java\jdk-25.0.2'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot
$upstreamLayout = (Split-Path $projectRoot -Leaf) -eq 'fewer-patches'
$patchRoot = $projectRoot
if ($upstreamLayout) { $projectRoot = Split-Path $projectRoot }
$buildRoot = Join-Path $projectRoot 'build'
$sourceRoot = Join-Path $projectRoot 'src/main/java'
$generatedRoot = Join-Path $buildRoot 'generated'
$classesRoot = Join-Path $buildRoot 'classes'
$supportRoot = Join-Path $buildRoot 'support'
$supportSource = Join-Path $supportRoot 'src/com/Zrips/CMI/Modules/ModuleHandling/CMIModule.java'
New-Item -ItemType Directory -Force (Split-Path $supportSource) | Out-Null
# This optional dependency is used only for compilation and is never packaged.
[IO.File]::WriteAllText($supportSource, 'package com.Zrips.CMI.Modules.ModuleHandling; public enum CMIModule { holograms; public boolean isEnabled() { throw new UnsupportedOperationException("compile-only stub"); } }')
& "$JavaHome/bin/javac.exe" -d "$supportRoot/classes" $supportSource
if ($LASTEXITCODE) { throw 'Compile-only CMI signature failed' }
function Convert-RelocatedSource([string]$content) {
    return $content.Replace('com.ryderbelserion.fusion.', 'libs.com.ryderbelserion.fusion.').Replace('org.spongepowered.configurate.', 'libs.org.spongepowered.configurate.').Replace('org.jspecify.', 'libs.org.jspecify.').Replace('com.zaxxer.hikari.', 'libs.com.zaxxer.hikari.')
}
$sourceFiles = if ($upstreamLayout) {
    @(
        'common/src/main/java/com/ryderbelserion/crazycrates/common/storage/impl/ConnectionFactory.java',
        'common/src/main/java/com/ryderbelserion/crazycrates/common/storage/holder/StorageHolder.java',
        'common/src/main/java/com/ryderbelserion/crazycrates/common/storage/impl/file/types/YamlFactory.java',
        'common/src/main/java/com/ryderbelserion/crazycrates/common/storage/impl/sql/types/SqliteFactory.java',
        'paper/src/main/java/com/badbones69/crazycrates/paper/tasks/crates/CrateManager.java',
        'paper/src/main/java/com/badbones69/crazycrates/paper/utils/MiscUtils.java'
    ) | ForEach-Object { Get-Item (Join-Path $projectRoot $_) }
} else { Get-ChildItem $sourceRoot -Filter '*.java' -Recurse -File }
foreach ($source in $sourceFiles) {
    $relative = if ($upstreamLayout) { $source.FullName.Substring($source.FullName.IndexOf('src\main\java\') + 'src\main\java\'.Length) } else { [IO.Path]::GetRelativePath($sourceRoot, $source.FullName) }
    $destination = Join-Path $generatedRoot $relative
    New-Item -ItemType Directory -Force (Split-Path $destination) | Out-Null
    [IO.File]::WriteAllText($destination, (Convert-RelocatedSource ([IO.File]::ReadAllText($source.FullName))))
}
$dependencies = Get-ChildItem $DependencyDirectory -Filter '*.jar' -File | Select-Object -ExpandProperty FullName
$annotations = Get-ChildItem $DependencyDirectory -Filter "annotations-*.jar" | Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
$classpath = (@($annotations, $OriginalJar, "$supportRoot/classes") + $dependencies) -join ';'
$arguments = @('-encoding', 'UTF-8', '-classpath', ('"' + $classpath.Replace('\', '/') + '"'), '-d', ('"' + $classesRoot.Replace('\', '/') + '"'))
$arguments += Get-ChildItem $generatedRoot -Filter '*.java' -Recurse -File | ForEach-Object { '"' + $_.FullName.Replace('\', '/') + '"' }
$argumentFile = Join-Path $buildRoot 'compile.args'
[IO.File]::WriteAllLines($argumentFile, $arguments)
& "$JavaHome/bin/javac.exe" "@$argumentFile"
if ($LASTEXITCODE) { throw 'Patched source compilation failed' }
$testSource = if ($upstreamLayout) { Join-Path $patchRoot 'LocationPersistenceRegression.java' } else { Join-Path $projectRoot 'src/test/java/LocationPersistenceRegression.java' }
$generatedTest = Join-Path $buildRoot 'generated-test/LocationPersistenceRegression.java'
New-Item -ItemType Directory -Force (Split-Path $generatedTest) | Out-Null
[IO.File]::WriteAllText($generatedTest, (Convert-RelocatedSource ([IO.File]::ReadAllText($testSource))))
$runtimeClasspath = "$classesRoot;$classpath"
& "$JavaHome/bin/javac.exe" -cp $runtimeClasspath -d "$buildRoot/test-classes" $generatedTest
if ($LASTEXITCODE) { throw 'Regression compilation failed' }
$mockitoAgent = Get-ChildItem $DependencyDirectory -Filter 'mockito-core-*.jar' | Select-Object -First 1 -ExpandProperty FullName
& "$JavaHome/bin/java.exe" "-Djava.io.tmpdir=$buildRoot" "-javaagent:$mockitoAgent" '-Dnet.bytebuddy.experimental=true' -cp "$buildRoot/test-classes;$runtimeClasspath" LocationPersistenceRegression
if ($LASTEXITCODE) { throw 'Regression failed' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$output = Join-Path $buildRoot 'CrazyCrates-5.2.0-fewer.2.jar'
Copy-Item -LiteralPath $OriginalJar -Destination $output -Force
$zip = [IO.Compression.ZipFile]::Open($output, [IO.Compression.ZipArchiveMode]::Update)
try {
    foreach ($class in Get-ChildItem $classesRoot -Filter '*.class' -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($classesRoot, $class.FullName).Replace('\', '/')
        $zip.GetEntry($relative)?.Delete()
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $class.FullName, $relative) | Out-Null
    }
    $descriptor = $zip.GetEntry('paper-plugin.yml')
    $reader = [IO.StreamReader]::new($descriptor.Open())
    $content = $reader.ReadToEnd().Replace("version: '5.2.0'", "version: '5.2.0-fewer.2'").Replace("version: '5.2.0-fewer.1'", "version: '5.2.0-fewer.2'")
    $reader.Dispose()
    $descriptor.Delete()
    $writer = [IO.StreamWriter]::new($zip.CreateEntry('paper-plugin.yml').Open())
    $writer.Write($content)
    $writer.Dispose()
} finally { $zip.Dispose() }
Write-Output $output
