# Changelog

## 2026-11-04 — 0.4.0 Password generator

### Added
- A Generate button under the password fields. It fills both fields with a random 20-character password (no look-alike characters such as 0/O or 1/l), copies it to the clipboard and shows it until you edit the fields.

## 2026-10-16 — 0.3.1 RAR fix

### Fixed
- RAR archives failed with "Unsupported Method" on every file. Homebrew's 7zz ships without the RAR codec, so the build now bundles the official 7-Zip 26.04 macOS binary (pinned by SHA-256), which includes it.
- Turning on "Protect with password" pushed the Cancel and Compress buttons below the bottom of the window. The window now grows to fit its content and is never shorter than 400pt.

### Changed
- Building from source no longer needs `brew install sevenzip`. `build.sh` downloads 7-Zip and verifies its checksum.

## 2026-10-15 — 0.3.0 Public release

### Added
- Public GitHub repo with download link, screenshots and install guide.

## 2026-10-15 — 0.3.0 Green brand, light mode

### Added
- Dark mode toggle (moon/sun button on the home screen), remembered across launches.

### Changed
- Ertaga kech brand green #3AD754 with black text on accent.
- Light mode is now the default.
- App icon: green zipper on a matte-black tile.

## 2026-10-15 — 0.2.0 Ertaga kech design

### Added
- About window: created by Anvar Narzullaev, with the Ertaga kech wordmark linking to t.me/ertagakech.

### Changed
- UI restyled to the Ertaga kech design system: Bricolage Grotesque and Geist Mono, glow backdrop.

## 2026-10-15 — 0.1.2 New icon

### Changed
- Minimal app icon: white zipper on a violet squircle, drawn in code.

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
