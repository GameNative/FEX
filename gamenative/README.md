# GameNative FEX patch series

This branch holds no FEX source. CI checks out an upstream `FEX-Emu/FEX` ref (default: the
newest `FEX-*` release tag), applies the patches listed in `series` in order with `git am`,
builds `libarm64ecfex.dll` and `libwow64fex.dll`, and packages them as a FEXCore `.wcp`.
The `main` and `upstream-main` branches of this repository mirror upstream and are not patched.

A patch that no longer applies fails the `source` job and names itself in the log. That is
the signal to rebase it or drop it. A patch is dropped when upstream merges the fix.

Version name: branch and PR builds are `<upstream release>-gn<SERIES_VERSION>-<branch sha>` with
versionCode 0, for example `2610-gn1-ab12cd3`. A `gn-<n>` tag builds a release: versionName
`<upstream release>-gn` with versionCode `SERIES_VERSION`, so the manifest id reads `2610-gn-4` and
a later series installs next to it. Bump `SERIES_VERSION` when the series changes and tag the
merged commit `gn-<SERIES_VERSION>` to release it.

## Series

One patch per source. The series is generic: nothing in it is keyed to a game, and every
behaviour that is not a plain correctness fix is behind an env var.

| Patch | From | What | Upstream |
|---|---|---|---|
| 0001 windows-fixes-for-protected-launchers | Dmage22/FEX-D2 `d2r/clean` (11 commits squashed) | Non-image section views, OS query for unknown executable pages, fault raise with `hlt` and the right exception code, stale NoExec retry (on the host exception path and in the FEX-2611 synchronous fault handler), PF/AF through context conversion (needs the ntdll export), disk-cache extents, compiler restart at inaccessible pages, `0x67` MOVS/STOS and FS/GS decode | analysis in FEX-Emu/FEX#5328; no PR yet |
| 0002 windows-anti-tamper-stepping-and-fault-delivery | tarikbc 0004, 0006, 0009, 0012, 0013, 0014, 0017 (v1.6.0, f4a686a0) squashed | Guest-visible protection of trapped pages, raw syscall return registers, volatile code regions, 512 MB code buffer, translation reuse, guest exceptions delivered straight into `KiUserExceptionDispatcher` on the guest stack (fast raise). Env gates: `FEX_EXP_SKIP_CALLRET_RESET=1` opts in; `FEX_EXP_FASTRAISE=0` opts out. The trapless fault path of tarikbc 0017 (`FEX_EXP_FASTTRAP`) is upstream since FEX-2611 and was dropped here. Volatile code regions were on by default here; 0004 makes them opt-in | FEX-Emu/FEX#6022, #6023; Wine bug 60461 |
| 0003 arm64ec-export-btcpu64notifynonimageviews | GameNative | Exports `BTCpu64NotifyNonImageViews` so ntdll only reports non-image views to a FEX that can take them | pairs with GameNative/proton-wine `dlls_arm64ec_emulator_notifications.patch` |
| 0004 windows-make-volatile-code-regions-opt-in | GameNative | Volatile code region detection (from 0003) runs only with `FEX_EXP_VOLATILE=1`; any other value or unset is off. On by default it misfires on JIT runtimes: TMNT: Shredder's Revenge (FNA/.NET) recompiles on its main thread, runs about 10x slower and never creates a D3D device. Age of Empires IV needs it and sets it in its overlay. Env gate: `FEX_EXP_VOLATILE=1` opts in | GameNative only |
| 0005 fexcore-fence-plain-loads-before-volatile-metadata-tso-loads | GameNative | With PE volatile metadata, a listed (TSO) load gets a `dmb ishld` in front when a plain load may precede it in the same metadata block, restoring x86 load order. Counter-Strike 2's CTSQueue pop let node->next and the tail sequence drift past its sequence re-check and crashed reading NULL+8. Outside metadata blocks nothing changes | GameNative only for now |
| 0006 fexofflinecompiler-load-the-config-before-initializing-logging | GameNative | The Windows offline compiler read `SilentLog` before any config was loaded and crashed at startup | to be sent upstream |
| 0007 codecache-rebase-relocation-offsets-to-the-code-buffer | GameNative | Since upstream #5840 relocation offsets are per compiled unit; the cache writer still stored them as code-buffer offsets, so every offline cache carried stale host pointers and un-rebased guest addresses. Offsets are rebased when a cache is generated or validated, and sorted on save | to be sent upstream |
| 0008 fexofflinecompiler-quote-process-all-child-arguments | GameNative | `process-all` passed child arguments unquoted, so exe names with spaces broke | to be sent upstream |
| 0009 codecache-copy-cached-code-to-a-writable-buffer-on-wow64 | GameNative | The WoW64 loader patched relocations into the read-only cache file mapping and killed the guest at start-up; it now gets a writable copy like ARM64EC (upstream #5658 covered ARM64EC only) | to be sent upstream |
| 0010 wow64-handle-exceptions-raised-before-the-first-thread | GameNative | The WoW64 exception handler read the thread state without a null check; a fault during `BTCpuProcessInit` (cache validation) killed the process silently. The overcommit path now runs before any thread access | to be sent upstream |
| 0011 codecache-keep-the-main-dispatcher-config-when-creating-the-validation-context | GameNative | The validation context's `InitCore` overwrote the shared signal handler config | to be sent upstream |
| 0012 windows-log-the-code-cache-load-phases-and-pre-thread-exceptions | GameNative | INFO lines for each phase of an offline cache load (map, copy, relocate, register, finalize, enable), visible with `FEX_SILENTLOG=0` | GameNative only |

Left out of 0002 on purpose: tarikbc 0002 (hides the emulator from the guest), 0007 (rewrites
ntdll export bytes to pass one game's hook check), 0008 (debug tool), 0010 (obsolete on Proton
11.0-2), 0016 (hooks `powrprof` from the exit thunk; the fix belongs in Wine, bug 60462).
Left out of 0001: dmage22's log-level change (cosmetic).

Patch 0002 was rebased onto 0001 by hand: the volatile-code and translation-reuse hooks in
`Core.cpp` sit after 0001's compile restart point, and the fast raise replaces the final
`NtRaiseException` in `RaiseException`. FEX-2611 delivers JIT-raised guest faults on arm64ec
without a host trap itself, so 0002's own trapless path went at the 2611 rebase, and 0001's stale
NoExec retry hooks upstream's synchronous handler as well as the host exception path.

Dropped at FEX-2611 because upstream merged them: the `NtDllRedirectionLUTSize` 32-bit load
(FEX-Emu/FEX#6021) and the kept-guest-loads IR change (FEX-Emu/FEX#6069).

Applies on `FEX-2611`.

## When upstream changes

`gamenative-upstream-check.yml` applies the series on the newest release tag and on upstream `main`
every Monday. A red run names the patch that no longer applies.

To move the series:

    gamenative/rebase.sh FEX-2611

It clones upstream at that ref, applies the series with a 3-way merge, and rewrites `patches/`
and `series` from the result. On a conflict it leaves the checkout in place and prints the
next commands: fix the file, `git am --continue` (or `git am --skip` when upstream already has
the fix), then `rebase.sh --regen <checkout>`. Afterwards update the table above and bump
`SERIES_VERSION`. The patch headers (author, subject, body, upstream links) survive the rewrite.

## Adding a patch

1. `git format-patch --no-signature --zero-commit -1 <sha>` on top of the applied series.
2. Put it in `patches/`, append its name to `series`, add a row above with the upstream link.
3. Bump `SERIES_VERSION`.
