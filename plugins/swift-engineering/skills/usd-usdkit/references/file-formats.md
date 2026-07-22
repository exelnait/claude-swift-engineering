# USD File Formats: USDA, USDC, USDZ

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

USD's data model is one thing; the **container** it's saved in is another — and USD gives you three, each suited to a different part of the pipeline. RealityKit reads all of them (`.usd`, `.usda`, `.usdc`, `.usdz`); the choice that actually matters is which one *you* author and hand off.

## USDA — ASCII, for people

USDA is a **plain-text** format — open one in a text editor and you'll read a structure not unlike source code: named blocks, properties, nesting. That has one enormous practical benefit: **USDA files are diffable and merge-resolvable**, the same way source code is. When two people edit the same USDA file, a version control tool can show what changed and, most of the time, merge non-overlapping edits automatically.

That's exactly why **Reality Composer Pro uses USDA as its scene format** — RCP projects are meant to be edited by more than one person (and reviewed as a diff), so paying the cost of a larger, slower-to-parse text file buys back mergeability. Reach for USDA for anything that's a collaborative *scene* — a file people or tools are actively hand-editing — rather than for a finished, heavy geometry asset.

## USDC — binary, for data

USDC is a **binary** format. Any USD-aware application can open one, but you can't read it as text or diff it meaningfully — a single changed vertex can rewrite most of the file's bytes. What you get in exchange is efficiency: USDC is much more compact and faster to load for large amounts of data, which in practice means **geometry**. A production-sized mesh — millions of points, normals, UVs — belongs in USDC, not USDA.

Rule of thumb: if an asset is *primarily geometry*, export it as USDC, even if it started life with materials attached in your DCC — you can layer materials back in separately (for example, built in Reality Composer Pro's Shader Graph rather than carried over verbatim).

## USDZ — zipped, for distribution

USDZ is a **zipped archive** — it takes a USD stage plus every dependency it needs (textures, referenced sub-layers, other assets) and bundles them into one self-contained file with an internal structure, like a package. That makes USDZ the right format for **publishing and distribution**: AR Quick Look, App Store Tags, sharing a finished asset with someone outside your pipeline, or embedding via the Safari Model tag (`conversion-and-web.md`) — one file, nothing missing.

The tradeoff: a USDZ **can't be edited in place** — you have to unzip it first to touch anything inside. Treat USDZ as an export target, not a working file. (Xcode's export dialog calls this option "Universal Scene Description Package" — same format.)

## Choosing in practice

| You're... | Use |
|---|---|
| Authoring/editing a scene multiple people (or Reality Composer Pro) will touch | **USDA** |
| Exporting a large geometry-heavy asset from a DCC | **USDC** |
| Shipping a finished, self-contained asset (AR, web, App Store) | **USDZ** |

A single pipeline typically uses all three at different stages: USDC for heavy per-asset geometry, USDA for the scene that references those assets together, USDZ for the final package that goes out the door.

## Common mistakes

1. **Authoring a collaborative scene as USDC.** You lose text-diffing and mergeability the moment two people need to edit concurrently — that's what USDA is for.
2. **Distributing a bare USDA/USDC alongside its textures as separate loose files.** Recipients have to manually gather dependencies. Package it as USDZ instead.
3. **Trying to hand-edit a USDZ.** It's zipped — unzip it first, edit the USDA/USDC inside, then re-zip or re-export. Don't expect to open it directly in a text editor.
4. **Assuming RealityKit only reads USDZ.** It reads `.usd`, `.usda`, `.usdc`, and `.usdz` — pick the format that suits *authoring*, not just the one you've seen used for AR.
