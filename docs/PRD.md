_Status: draft v1 · macOS menu bar app_

## 1. Summary

modelbox is a macOS menu bar app that scans every place local AI models are stored on the Mac and presents one unified view: each model's source app, on-disk size, estimated RAM to load, a "runs on this Mac?" verdict, and duplicates across apps that can be reclaimed.

A second tab lets the user browse models available to download — filtered by lab and size — and hands the download off to the appropriate tool rather than downloading in-app.

Settings live in a footer-triggered separate window, keeping the popover focused on two tabs: **Overview** and **Explorer**.

## 2. Problem

Several local-AI apps each download model weights into their own directories (Ollama, OpenWhispr, and various GGUF-based desktop apps under Application Support, plus the Hugging Face cache and LM Studio when present). There is no single place to answer:

- What models actually live on this Mac, and where?
- How much disk and RAM does each consume?
- Which models are duplicated across apps and can be safely reclaimed?
- Can a given model even run on this machine's RAM?

The weights are large (multi-GB each), so this fragmentation quietly wastes tens of gigabytes. A cross-app inventory + dedup view is the core value.

## 3. Goals / non-goals

**Goals**
- One cross-app inventory of local models.
- True disk-usage accounting and duplicate detection.
- RAM-fit guidance ("runs on this Mac").
- Low-friction discovery of new models to download.
- Safe, explicit cleanup — never destructive without confirmation.

**Non-goals (v1)**
- Running inference.
- Downloading models in-app.
- Automatic deduplication.
- Per-model usage tracking.
- Benchmarks (deferred to v1.1).

## 4. Users & top pain points

- Visibility and deduplication across a fragmented local-model ecosystem.
- Seeing RAM requirement, license, and context length before committing to a multi-GB download.
- A clear "runs on this Mac" indicator.
- Cleaning up unused or duplicate weights to reclaim disk.

## 5. v1 features

### Tab 1 — Overview (local models)

- Scan all known storage locations (§7) plus any user-added custom paths; live-refresh via a file-system watcher.
- Per-model row: name, **source app**, format (GGUF / safetensors / content-addressed blob), disk size, **estimated RAM**, **"runs on this Mac" badge** (fits / tight / too big, compared against `hw.memsize`), last-modified date, and quantization/parameter count when derivable.
- Aggregate header: total models, total disk used, reclaimable space.
- **Duplicate detection:** group byte-identical models (shared content hash or shared content-addressed blob digest) and surface "N copies — reclaim X GB".
- **Guarded actions:** "Reveal in Finder" and "Delete", with delete behind an explicit confirmation dialog. No automatic actions.

### Tab 2 — Explorer (discover models)

- Browse the Hugging Face Hub via its free REST API.
  - Filter **by lab** (author/org), **by size** (parameter-count range), and **by format** (e.g. GGUF / MLX).
  - Sort by downloads / trending / last-modified.
- Per-result: name, lab, parameter size, downloads, approximate download size, and license/context length when available (lazy model-card fetch).
- **"Already installed" flag** by cross-referencing the Overview inventory.
- **Inform + hand off:** show a copyable command (e.g. `ollama pull …`) and/or "Open model page". No in-app download engine in v1.
- Offline-graceful: cache the last results, show a "last synced" timestamp, and disable network actions when offline.

### Settings (footer → separate window)

- Manage scan locations: add/remove custom paths, toggle each known source on/off.
- Optional Hugging Face token (raises API rate limit).
- RAM-estimate tuning factor.
- Launch at login, auto-update, refresh interval.

## 6. UX shell

A menu bar popover (~360×520) with a tab switcher at the top, content area, a divider, and a footer (Settings · Refresh · Quit). Settings opens as an independent macOS window. Native appearance with a template menu-bar icon that follows light/dark mode.

## 7. Scan sources (v1)

| Source | Path | On-disk format | Notes |
|---|---|---|---|
| Ollama | `~/.ollama/models` | manifests + sha256 blobs | sum referenced blobs for true size; digests are free dedup keys |
| Hugging Face cache | `~/.cache/huggingface/hub` | blobs + snapshots (symlinks) | content-addressed; honor `HF_HOME` / `HF_HUB_CACHE` |
| LM Studio | `~/.lmstudio/models`, `~/.cache/lm-studio` | flat GGUF | present only if installed |
| OpenWhispr | `~/.cache/openwhispr/models` (+ `embedding-models`) | flat GGUF | real data present on target machine today |
| App Support sweep | `~/Library/Application Support/*/models/*.gguf` | flat GGUF | covers GGUF-based desktop apps generically |
| Custom | user-added | any | configured in Settings |

**RAM estimate:** baseline `disk_size × ~1.2`, refined by parameter count and quantization when known.

**Deduplication:** equal content-addressed digests (Ollama / HF) are free dedup signals; flat GGUF files are compared by size + name first and confirmed by an on-demand content hash. Hashing multi-GB files is lazy and off the main thread — never on every refresh.

## 8. Out of scope / later (v1.1+)

- **Benchmarks tab** sourced from a free, programmatically-accessible leaderboard (e.g. the Hugging Face Open LLM Leaderboard dataset, or LMArena). Note: artificialanalysis.ai has no public API and scraping likely violates its ToS — at most, offer an "open in browser" link.
- Per-model usage tracking (which model is actually loaded/used).
- In-app downloader (resumable, hash-verified).
- Automatic dedup / blob symlinking.

## 9. Technical approach

Native SwiftUI macOS app, Swift Package Manager, `MenuBarExtra(.window)` scene plus a native `Settings {}` scene triggered from the footer. Sparkle for auto-update; `Makefile` for build/bundle/sign; changesets + GitHub Actions for releases and the appcast.

Core domain modules:
- `Model` value type: id, name, source app, path, format, size, estimated RAM, digest/hash, modified date, quant, params.
- `ModelScanner` protocol with per-source scanners (Ollama, HF cache, flat-GGUF folders, custom paths).
- `ModelStore` aggregating scanners, watching paths, computing totals.
- `DedupDetector` grouping by content hash / shared digest.
- `HardwareInfo` reading `hw.memsize` for the "runs on this Mac" verdict.
- `HuggingFaceClient` for Explorer (author/params/library filters, lazy card fetch, response cache).

A generic directory watcher (kqueue + debounce) keeps the inventory live without polling.

## 10. Success criteria

1. The 5.7 GB OpenWhispr Qwen model appears in Overview with correct size, RAM estimate, and source.
2. A deliberately duplicated copy is flagged as reclaimable.
3. Explorer returns Hugging Face results filtered by lab + size and marks already-installed models.
4. Offline, Explorer shows cached results with a "last synced" timestamp.
5. The footer "Settings" action opens a separate window, and settings persist across relaunch.
