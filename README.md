# Siqaman

A native, Apple-style macOS archiver. Compress to **ZIP** or **7z** (optionally AES-256 password-protected), extract **ZIP, RAR, 7z, tar, gz, bz2, xz** and more — from a window, by drag & drop, double-click, or Finder's right-click menu.

## Install

Requires macOS 15+, Command Line Tools (`xcode-select --install`) and Homebrew's 7-Zip:

```bash
brew install sevenzip
```

```bash
./build.sh
```

This builds `build/Siqaman.app` (bundling its own copy of `7zz`), installs it to `/Applications`, and registers the Finder services. `./build.sh --no-install` only builds.

## Use

- **Finder:** right-click files → **Services → Compress with Siqaman…** or **Extract with Siqaman**.
  (If missing: System Settings → Keyboard → Keyboard Shortcuts → Services → Files and Folders, tick both.)
- **Window:** drop files to compress; drop archives to extract.
- **Double-click / Open With:** Siqaman is registered as an alternate handler for archives. To make it the default, Finder → Get Info on an archive → Open with → Siqaman → Change All.

Extraction lands next to the archive. A single top-level item is lifted out (no `Foo/Foo/` nesting), `.tar.gz` style archives are fully unpacked, and existing files are never overwritten (`Name 2`, `Name 3`…). Encrypted archives prompt for a password. Passwords are passed to 7-Zip over stdin, never on the command line.

## Formats

| | Create | Extract | Password |
|---|---|---|---|
| ZIP | ✓ | ✓ | AES-256 (create), ZipCrypto/AES (extract) |
| 7z | ✓ | ✓ | AES-256, optional encrypted file names |
| RAR / RAR5 | — | ✓ | ✓ |
| tar, gz, bz2, xz, zst, cab, iso… | — | ✓ | — |

RAR creation is not possible: the format is proprietary.

## Project structure

```
Sources/Siqaman/
  SiqamanApp.swift   app entry, window, Finder services
  Model.swift        UI state machine (compose → working → password → done)
  ContentView.swift  SwiftUI screens
  Archiver.swift     7zz wrapper: compress, extract, progress, password detection
Resources/
  Info.plist         services, document types, RAR/7z UTIs
scripts/
  icon.swift         draws the app icon (vector, 1024px)
  selftest.swift     engine self-test
build.sh             build, bundle, sign (ad-hoc), install
```

## Test

```bash
swiftc -parse-as-library -enable-bare-slash-regex -swift-version 5 Sources/Siqaman/Archiver.swift scripts/selftest.swift -o build/selftest && build/selftest
```
