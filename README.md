# <img src="Sources/Modelbox/Resources/AppIcon.svg" alt="" height="48" valign="middle" /> modelbox

Native macOS menu bar app for seeing and managing the local AI models on your Mac.

See [docs/PRD.md](docs/PRD.md) for the full spec.

## What it does

- **Overview** - scans every place local models live (Ollama, the Hugging Face cache, LM Studio, and GGUF model folders under Application Support) and shows each model's source, on-disk size, estimated RAM, and the duplicates you can reclaim.
- **Explorer** - browse models available to download, filtered by lab and size, then hand the download off to the right tool.

Settings open from the footer as a separate window.

## Build & run

Requires macOS 26+ and a Swift 6.2 toolchain.

```sh
make bundle    # produces ./Modelbox.app, ad-hoc signed
make run       # builds and opens
make install   # copies to /Applications
make clean
```

Run tests with `swift test`.

## Architecture

Native SwiftUI under `Sources/Modelbox/`:

- **Models** - `LocalModel` (one model on disk) and `ModelStore` (the in-memory inventory the views read).
- **Services** - leaf utilities such as `DirectoryWatcher`; model scanners and the Hugging Face client land here as they are built.
- **Views** - `PopoverView` is the menu-bar entry point (Overview + Explorer tabs); `SettingsView` is the separate settings window.

## Auto-updates

Powered by [Sparkle](https://sparkle-project.org). The release pipeline (signing keys, appcast, GitHub Actions) is configured separately before automated releases can run.
