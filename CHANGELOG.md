# Changelog

## 2026-10-15 — 0.1.1 Security fixes

### Fixed
- Extracted files now keep the archive's quarantine flag, so Gatekeeper still checks downloaded apps.
- File names with `*` or `?` are archived literally instead of matching other files.
- A corrupt archive is no longer reported as "wrong password".
- Cancel pressed the instant a job starts is no longer lost.

## 2026-10-15 — 0.1.0 Initial release

### Added
- Native SwiftUI archiver window with drag & drop, light/dark mode, live progress and cancel.
- Compress to ZIP or 7z with Fast/Balanced/Smallest levels and AES-256 password protection (7z can encrypt file names).
- Extract ZIP, RAR, RAR5, 7z, tar, gz, bz2, xz and more, with password prompt and retry.
- Finder right-click services: "Compress with Siqaman…" and "Extract with Siqaman".
- Smart extraction: lifts single top-level items, unpacks .tar.gz fully, never overwrites existing files.
- `build.sh` builds, bundles 7-Zip, signs ad-hoc and installs to /Applications.
