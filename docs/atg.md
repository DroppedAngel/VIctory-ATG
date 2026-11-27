# VIctory-ATG

VIctory-ATG is [Vice-Tay](https://github.com/TaynanGT/Vice-Tay) `cc9ed86c7` with the fixes below
taken from other VIctory forks, and a desktop launcher for 8 GB NVIDIA cards. Its history is joined
to [Marvisak/VIctory](https://github.com/Marvisak/VIctory) `63bcca4` by a merge that keeps
Vice-Tay's tree. Git therefore counts upstream's commits up to `63bcca4` as merged, although only
the ones Vice-Tay ported are in the code. Later upstream fixes are ported by hand, as Vice-Tay does.

## Why Vice-Tay

On 2026-11-26, 46 forks with their own commits were compared (of 2,022 forks, 983 had pushed
anything). Vice-Tay was chosen as the base for three reasons:

- It has the best measured frame rate: 21.1 fps at the median of a 30-minute hand-played session on
  an RTX 4090, Series S, against about 1 fps upstream.
- It has the only long stability record: 30 minutes with no crash, and memory grew by about 1 GB.
- Its CI gates merges.

The other fast trees are older snapshots or subsets of it. Victory-United is Vice-Tay `fab5286c`
plus documents, and Hail-to-the-Thief is AvatarManz `126acb35` plus 3 commits.

## What was taken

| Change | From | Why |
|---|---|---|
| A program's constant table starts after its instructions, translator version 3 | jennydeth `b43dcc98f`, `e570317f5` (upstream #2143) | About 630 MB less video memory on an RTX 3060 |
| Large `XMemAllocDefault` blocks are write-watched (`VICTORY_XMEM_WATCHED=0`: not) | Biskwit `f5ef19e39` | A 21 MB block copied whole twice a frame (4.4 ms) now costs 0.1 ms |
| Null descriptors made once and copied | Kitsune `d407e3f0d` | `sync_heaps` spent 15-250 ms a frame making them on an RTX 3050 |
| `extrq`/`insertq` (AMD only) jump to SSE2 stubs after the first fault (`VICTORY_PATCH_SSE4A=0`: not) | 101Leafy `8c637d63a` | Intel processors fault on every one of them |
| Comparison-sampler pipelines kept out of the library; translated shaders carry a hash part; no pipeline library on NVIDIA (`VICTORY_LIBRARY_LOAD=1`: load it) | Biskwit `93480d7ec`, `535ed7362`, `d8388ae5b` | Flat bands of colour in 5 of 6 warm launches on an RTX 4090 with the library, none without (Vice-Tay issue #44) |
| The space below 4 GiB is kept for the title's 32-bit memory | upstream `d1dfbbd4d` (#1009) | Startup failed 2 of 3 times on an RTX 2080 without it |
| Raw title copies keep a still-valid write-watch query | Vice-Tay `e11801e6e` (its PR #91) | 11.1 to 2.1 us a query |
| Decoration-bake coverage tracked per descriptor heap | Vice-Tay `7eef14365` (its PR #85) | Missing or grey bakes |
| A dispatch's compute pipeline is made first and waited for | Biskwit `0b6c0e46f` | Cold launches kept the main character's head |
| A cache entry that another publisher wrote first is accepted | upstream `a73d59e07` (#1324) | A race on Windows |

Each was cherry-picked with `-x`, so its commit names the original.

## The desktop launcher

- `Play-VIctory.cmd` runs with Windows PowerShell when PowerShell 7 is not installed. Before, it
  failed on a double-click on a Windows without PowerShell 7. On an error it keeps its window open.
- `scripts\play.ps1` no longer needs `-Exe`. It takes the executable started last time (kept in
  `%LOCALAPPDATA%\victory\play-exe.txt`) or asks for it once.
- `scripts\play.ps1` uses whichever build exists, also under `CARGO_TARGET_DIR`.
- `-Machine auto` reads the card's video memory from the registry and picks the preset from it:
  - `3070` on NVIDIA cards with 8 GB or less: the 4070 threads (8/6/4), with 1024 MB of card
    buffers of 128 KiB and up and 512 MB of card windows. Under 896 MB the buffers spilled to PCIe
    on Kitsune's 6 GB card, and 64 KiB buffers lost the device there.
  - `4070` on other NVIDIA cards with fewer than 32 logical processors.
  - `4090` otherwise.
- `-Console` defaults to `series-s` on cards with 12 GB or less.
- `scripts\install-desktop.ps1` puts a VIctory shortcut on the desktop and in the Start menu
  (`-Remove` takes them away).

## Not taken yet

These are opt-in, or unmeasured with the title, and wait for a run on the 8 GB card:

- Omega `ee8a23712` (`VICTORY_TEXTURE_DROP_MIPS`): two conflicts to resolve.
- Omega `c9c31c7e1` (`VICTORY_GUARD_SPIN`): three conflicts.
- Vice-Tay PR #92 (readback pool).
- Omega `3615e6fb7` (2 MB refresh pieces).

## Frame rate

The title paces itself to 30 fps, and `VICTORY_FRAME_INTERVAL_MS` lifts that only once frames are
under 33 ms. Vice-Tay's frame is CPU-bound: 34 of its 47 ms go to preparation on the submitting
thread. Expect 10-20 fps in the world on an RTX 3070. The research behind these numbers is in the
Jarvis notes `victory-perf-2026-11-26.md`.
