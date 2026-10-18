# GameNative FEX patch series

This branch holds no FEX source. CI checks out an upstream `FEX-Emu/FEX` ref (default: the
newest `FEX-*` release tag), applies the patches listed in `series` in order with `git am`,
builds `libarm64ecfex.dll` and `libwow64fex.dll`, and packages them as a FEXCore `.wcp`.
The `main` and `upstream-main` branches of this repository mirror upstream and are not patched.

A patch that no longer applies fails the `source` job and names itself in the log. That is
the signal to rebase it or drop it. A patch is dropped when upstream merges the fix.

Version name: `<upstream release>-gn<SERIES_VERSION>-<branch sha>`, for example `2610-gn1-ab12cd3`.
Bump `SERIES_VERSION` when the series changes.

## Series

One patch per source. The series is generic: nothing in it is keyed to a game, and every
behaviour that is not a plain correctness fix is behind an env var.

| Patch | From | What | Upstream |
|---|---|---|---|
| 0001 windows-fixes-for-protected-launchers | Dmage22/FEX-D2 `d2r/clean` (11 commits squashed) | Non-image section views, OS query for unknown executable pages, fault raise with `hlt` and the right exception code, stale NoExec retry, PF/AF through context conversion (needs the ntdll export), disk-cache extents, compiler restart at inaccessible pages, `0x67` MOVS/STOS and FS/GS decode | analysis in FEX-Emu/FEX#5328; no PR yet |
| 0002 arm64ec-load-ntdllredirectionlutsize-as-32-bits | tarikbc 0015 + upstream 3a2b1c0b43 | 32-bit load of `NtDllRedirectionLUTSize`; `b.hs` bounds check so an offset equal to the size no longer reads past the LUT | FEX-Emu/FEX#6021, fully merged (both commits). Drop at FEX-2611 |
| 0003 windows-anti-tamper-stepping-and-fault-delivery | tarikbc 0004, 0006, 0009, 0012, 0013, 0014, 0017 (v1.6.0, f4a686a0) squashed | Guest-visible protection of trapped pages, raw syscall return registers, volatile code regions, 512 MB code buffer, translation reuse, guest faults without a host trap with the exception code picked per signal (SIGILL, SIGTRAP, SIGSEGV). Env gates: `FEX_EXP_SKIP_CALLRET_RESET=1` opts in; `FEX_EXP_FASTTRAP=0`, `FEX_EXP_FASTRAISE=0` opt out | FEX-Emu/FEX#6022, #6023; Wine bug 60461 |
| 0004 arm64ec-export-btcpu64notifynonimageviews | GameNative | Exports `BTCpu64NotifyNonImageViews` so ntdll only reports non-image views to a FEX that can take them | pairs with GameNative/proton-wine `dlls_arm64ec_emulator_notifications.patch` |

Left out of 0003 on purpose: tarikbc 0002 (hides the emulator from the guest), 0007 (rewrites
ntdll export bytes to pass one game's hook check), 0008 (debug tool), 0010 (obsolete on Proton
11.0-2), 0016 (hooks `powrprof` from the exit thunk; the fix belongs in Wine, bug 60462).
Left out of 0001: dmage22's log-level change (cosmetic).

Patch 0003 was rebased onto 0001 by hand in three places: the volatile-code and translation-reuse
hooks in `Core.cpp` sit after 0001's compile restart point, and the fast-raise call in
`RethrowGuestException`. The two fault paths compose: 0003's trapless branch runs first, and
0001's `hlt` is the fallback when `FEX_EXP_FASTTRAP=0`.

Applies on `FEX-2610`. On upstream `main` after 2026-10-12 it applies without 0002.

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
