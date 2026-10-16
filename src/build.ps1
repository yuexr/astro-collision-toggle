param([string]$Zig = 'zig')

$ErrorActionPreference = 'Stop'
$version = '1.0.1'
$root = Split-Path -Parent $PSScriptRoot
$build = Join-Path $root 'build'
$libs = Join-Path $root 'libs/minhook'
$mod = Join-Path $build 'CollisionToggle'
$scripts = Join-Path $mod 'Scripts'

New-Item -ItemType Directory -Path $scripts -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'CollisionToggle/enabled.txt') -Destination $mod
Copy-Item -LiteralPath (Join-Path $root 'CollisionToggle/MinHook-LICENSE.txt') -Destination $mod
Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $mod 'LICENSE')
foreach ($name in @('main.lua','camera.lua')) {
    Copy-Item -LiteralPath (Join-Path $root "CollisionToggle/Scripts/$name") -Destination $scripts
}

$compilerArgs = @(
    'cc', '-target', 'x86_64-windows-gnu', '-O2', '-Wall', '-Wextra', '-Werror',
    '-I', (Join-Path $libs 'include'), '-shared',
    (Join-Path $PSScriptRoot 'native.c'),
    (Join-Path $libs 'src/buffer.c'),
    (Join-Path $libs 'src/hook.c'),
    (Join-Path $libs 'src/trampoline.c'),
    (Join-Path $libs 'src/hde/hde64.c'),
    '-o', (Join-Path $scripts 'CollisionToggleNative.dll'), '-lkernel32'
)
$oldLocalCache = $env:ZIG_LOCAL_CACHE_DIR
$oldGlobalCache = $env:ZIG_GLOBAL_CACHE_DIR
try {
    $env:ZIG_LOCAL_CACHE_DIR = Join-Path $build 'zig-local'
    $env:ZIG_GLOBAL_CACHE_DIR = Join-Path $build 'zig-global'
    & $Zig @compilerArgs
    if ($LASTEXITCODE -ne 0) { throw 'Native build failed.' }
} finally {
    $env:ZIG_LOCAL_CACHE_DIR = $oldLocalCache
    $env:ZIG_GLOBAL_CACHE_DIR = $oldGlobalCache
}

# Package only runtime files, without compiler output or saved session state.
$package = Join-Path $build 'package/CollisionToggle'
New-Item -ItemType Directory -Path (Join-Path $package 'Scripts') -Force | Out-Null
foreach ($name in @('enabled.txt','MinHook-LICENSE.txt','LICENSE')) {
    Copy-Item -LiteralPath (Join-Path $mod $name) -Destination $package
}
foreach ($name in @('main.lua','camera.lua','CollisionToggleNative.dll')) {
    Copy-Item -LiteralPath (Join-Path $scripts $name) -Destination (Join-Path $package 'Scripts')
}

$archive = Join-Path $root "Collision-Toggle-$version-UE4SS.zip"
Compress-Archive -LiteralPath $package -DestinationPath $archive -Force
Write-Host "Built $archive"
