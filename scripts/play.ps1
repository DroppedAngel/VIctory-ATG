# Starts the title with the settings this fork is played with (README.md, "Getting started").
#   scripts\play.ps1 -Exe <path of your own copy's executable>
# Without -Exe it takes the executable it started last time, or asks for it once.
# -Safe         without the newer, faster ways (the first thing to try when something is wrong)
# -RayTracing   the title's own ray-traced indirect light: lit interiors, about a third slower
# -Windowed     a window instead of the whole screen (full screen is the default)
# -NoPanel      without the performance panel (on by default, F3 hides it while playing)
# -Console      series-x (the default) or series-s: the console the title takes this PC for
# -Build        target\diag (the default, the build all measurements are of) or target\release
# -Machine      auto (the default: by the graphics card), 7900xtx, 4070 or 4090
# -More         other settings: -More @{VICTORY_PANEL='1'} or -More @{VICTORY_AMBIENT='1.0'}
# On a smaller NVIDIA PC, compare the same Series S scene after a fresh start
# with one override at a time, e.g. -More @{VICTORY_LAND_THREADS='3'} for
# copy-back work, or -More @{VICTORY_THIN_THREADS='6'} for list translation.
# Run it from a normal window, not as administrator: the driver then keeps its shader cache elsewhere.
param(
    [string]$Exe,
    [switch]$Safe,
    [switch]$RayTracing,
    [switch]$Windowed,
    [switch]$NoPanel,
    [ValidateSet('series-x', 'series-s')][string]$Console,
    [ValidateSet('diag', 'release')][string]$Build = 'diag',
    [ValidateSet('auto', '7900xtx', '3070', '4070', '4090')][string]$Machine = 'auto',
    [hashtable]$More = @{}
)
$settings = @{
    VICTORY_TEXTURE_NO_WAIT = '1'; VICTORY_RELAY = '2'; VICTORY_WIDE_BACK = '1'; VICTORY_CARD_REHASH_RUNS = '1'
    VICTORY_JOIN_COPIES = '1'; VICTORY_INDIRECT_WINDOW = '1'; VICTORY_RELAY_COPY = '1'; VICTORY_CARD_STEPS = '2'
    VICTORY_TITLE_PRIORITIES = '0'
    VICTORY_SHOW_AFTER = '1'; VICTORY_AMBIENT = '0.8'; VICTORY_D3D12_DRED = 'light'
}
# The video memory of the largest NVIDIA or AMD card, in bytes (0 when Windows does not say).
# Win32_VideoController stops at 4 GB, so it is read from the display class in the registry.
$vram = 0
$display = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
foreach ($key in @(Get-ChildItem $display -ErrorAction SilentlyContinue)) {
    $info = Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue
    if ($info -and $info.MatchingDeviceId -match 'ven_(10de|1002)') {
        $size = $info.'HardwareInformation.qwMemorySize'
        if ($size -and [uint64]$size -gt $vram) { $vram = [uint64]$size }
    }
}
$threads = [Environment]::ProcessorCount
if ($Machine -eq 'auto') {
    $cards = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object { $_.PNPDeviceID })
    if (-not ($cards -match 'VEN_10DE')) {
        $Machine = '7900xtx'
    } elseif ($vram -gt 0 -and $vram -le 8GB) {
        # 8 GB cards: the 4070 threads with smaller video memory budgets.
        $Machine = '3070'
    } elseif ($threads -lt 32) {
        # The 4090 block's 12/8/6 threads are for 32 logical processors; with
        # fewer they slow the frame (Biskwit a37dbb5f3: i9-12900K, 24 threads,
        # 58-60 -> 54-56 ms a frame with fewer).
        $Machine = '4070'
    } else {
        $Machine = '4090'
    }
}
if (-not $Console) {
    # Series S on cards of 12 GB or less: about 5 GB less memory and faster
    # (README, "Latest sessions"), and the Series X picture does not fit them.
    $Console = if ($vram -gt 0 -and $vram -le 12GB) { 'series-s' } else { 'series-x' }
}
if ($Machine -eq '7900xtx') {
    # i9-12900K, RX 7900 XTX, 64 GB: the page-mapping lock was fastest with one
    # thread, and the AMD driver lowers its clocks between submissions.
    $settings.VICTORY_MAP_THREADS = '1'; $settings.VICTORY_CARD_AWAKE = '1'
} else {
    # RTX 4090, Ryzen 9 9950X3D (16 cores of one kind, two caches), 48 GB.
    # NVIDIA sets its clocks by the driver's power mode: no spinner on the
    # compute queue. 16 cores record and land, not 8.
    $settings.VICTORY_THIN_THREADS = '12'; $settings.VICTORY_UNDER_THREADS = '8'; $settings.VICTORY_LAND_THREADS = '6'
    if (-not $Safe) {
        # Pages are mapped by several threads only while the title streams
        # (not the default: one run behind it).
        $settings.VICTORY_MAP_THREADS = 'auto'
        # A fill of the constant-buffer ring that a small copy at its place writes
        # into refused the whole submission to the card steps; in list order it is
        # taken (submit thread 104.7 -> 50.9 ms a frame, 12.1 -> 14.3 fps here).
        $settings.VICTORY_PLACED_ORDER = '1'
    }
    # The console wave64 programs a 32-lane card takes only in the wave-wide
    # form; this list of them ran without a lost device on this card for 30
    # minutes (the losses of runs 121-124 had the form on for every program).
    # Kept under -Safe too: without it those programs do not translate and
    # their draws are dropped, the picture -Safe is there to check.
    $settings.VICTORY_WAVE_WIDE_ONLY = '6f225b641c5b0708,5dc3b25986622949,369cbe906ea72764,2cc4c197ee29e291'
}
if ($Machine -eq '4070' -or $Machine -eq '3070') {
    # Ryzen 7 7800X3D: eight physical cores, versus the 4090 test PC's sixteen.
    # Keep the same wave64 allowlist and rendering profile; spend VRAM on
    # shader buffers before textures consume it. No approximate shader modes.
    $settings.VICTORY_THIN_THREADS = '8'; $settings.VICTORY_UNDER_THREADS = '6'; $settings.VICTORY_LAND_THREADS = '4'
    $settings.VICTORY_MAP_THREADS = '1'; $settings.VICTORY_PIPELINE_WORKERS = '3'
    if (-not $Safe) {
        $settings.VICTORY_CARD_RESERVE_BUDGETS = '1'
        $settings.VICTORY_CARD_BUFFERS_MIN_KB = '64'; $settings.VICTORY_CARD_BUFFERS_MB = '1536'
        $settings.VICTORY_CARD_WINDOWS_MB = '1024'
    }
}
if ($Machine -eq '3070' -and -not $Safe) {
    # 8 GB cards (RTX 3070, 3060 Ti, 4060 Ti 8 GB): the 4070 block's budgets
    # spill out of video memory there. 1,015 MB holds every buffer of 64 KiB
    # and up, and under 896 MB they spill to PCIe (Kitsune docs/perf-notebook.md,
    # RTX 3050 6 GB); 64 KiB buffers lost the device on 6 GB, 128 KiB did not.
    $settings.VICTORY_CARD_BUFFERS_MIN_KB = '128'; $settings.VICTORY_CARD_BUFFERS_MB = '1024'
    $settings.VICTORY_CARD_WINDOWS_MB = '512'
}
# -Safe leaves out every way still on trial, and the newest faster ones.
if ($Safe) {
    $settings.VICTORY_UNDER_WIDE = '0'; $settings.VICTORY_LAND_ECHO = '0'
} else {
    $settings.VICTORY_THIN = '1'; $settings.VICTORY_JOIN_PARTS = '8'; $settings.VICTORY_UPLOAD_AHEAD = '1'
    # A dispatch does not end a batch of argument clamps before the title waits
    # for it: off by default, as other ways the title may wait are not known.
    $settings.VICTORY_INDIRECT_BATCH = '2'
}
if ($RayTracing) { $settings.VICTORY_BVH_BUILDER = '1' }
# The whole screen, with no frame, as on the console.
if (-not $Windowed) { $settings.VICTORY_FULLSCREEN = '1' }
# The performance panel (FPS, frame times, GPU, CPU, VRAM, RAM) in the upper left
# corner, so clips and screenshots show what the build runs at and on what PC.
if (-not $NoPanel) { $settings.VICTORY_PANEL = '1' }
foreach ($k in $More.Keys) { $settings[$k] = $More[$k] }

$ram = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory
Write-Host "Settings for the $Machine, $Console$(if ($Safe) { ', safe' })$(if ($RayTracing) { ', with ray tracing' })."
if ($Console -eq 'series-s' -and $Machine -eq '4090') {
    Write-Host ("Series S requests {0} list translation threads, {1} for memory updates, and {2} for landing." -f
        $settings.VICTORY_THIN_THREADS, $settings.VICTORY_UNDER_THREADS, $settings.VICTORY_LAND_THREADS)
}
if ($ram -and $ram -lt 60GB) {
    Write-Host ("Windows reports {0:N1} GiB of physical RAM. Keep a system-managed page file. See docs/measurements.md for measured Series S memory use." -f ($ram / 1GB))
}

# victory.exe of the build asked for, else of the other one, in CARGO_TARGET_DIR
# when it is set (README.md, short build paths), else in target.
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$targets = @()
if ($env:CARGO_TARGET_DIR) { $targets += $env:CARGO_TARGET_DIR }
$targets += Join-Path $root 'target'
$builds = @($Build) + @(@('diag', 'release') | Where-Object { $_ -ne $Build })
$victory = $null
foreach ($b in $builds) {
    foreach ($t in $targets) {
        $candidate = Join-Path (Join-Path $t $b) 'victory.exe'
        if (-not $victory -and (Test-Path $candidate)) { $victory = $candidate; $Build = $b }
    }
}
if (-not $victory) { Write-Host "No victory.exe in $($targets -join ' or '). Build it first (README.md)."; exit 1 }

# The executable: -Exe, else the one started last time, else asked for once.
$last = Join-Path $env:LOCALAPPDATA 'victory\play-exe.txt'
if (-not $Exe -and (Test-Path $last)) {
    $saved = (Get-Content $last -TotalCount 1 -ErrorAction SilentlyContinue)
    if ($saved -and (Test-Path $saved)) { $Exe = $saved }
}
if (-not $Exe) {
    Add-Type -AssemblyName System.Windows.Forms
    $pick = New-Object System.Windows.Forms.OpenFileDialog
    $pick.Title = "Your copy's executable"
    $pick.Filter = 'Executable (*.exe)|*.exe'
    if ($pick.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { Write-Host 'No executable picked.'; exit 1 }
    $Exe = $pick.FileName
}
if (-not (Test-Path $Exe)) { Write-Host "No $Exe."; exit 1 }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force (Split-Path $last) | Out-Null
Set-Content -Path $last -Value $Exe -Encoding utf8
Write-Host "Starting $Exe with $victory."

# (Other settings left over in this window go; where your files are stays.)
$paths = 'VICTORY_CONFIG', 'VICTORY_GAME_DIR', 'VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR'
$inherited = @(Get-ChildItem Env:VICTORY_* | Where-Object { $_.Name -notin $paths })
foreach ($entry in $inherited) { Remove-Item "Env:$($entry.Name)" }
foreach ($k in $settings.Keys) { Set-Item "Env:$k" $settings[$k] }
$discarded = $inherited | Where-Object {
    $_.Name -notin $More.Keys -and -not $_.Value.Equals([Environment]::GetEnvironmentVariable($_.Name))
} | Sort-Object Name
if ($discarded) {
    Write-Host "Discarded inherited values for $($discarded.Name -join ', '). Use -More to pass them explicitly."
}
Push-Location $root   # victory.toml is looked for here
try { & $victory run $Exe --console $Console --execute } finally { Pop-Location }
# Its exit code, so Play-VIctory.cmd keeps the window open on an error.
exit $LASTEXITCODE
