# Changelog

All notable changes to FreeMyMacOS. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [1.0.1] - 2026-11-18

### Added
- Turkish and German interface; numbers and sizes follow your region (23,94 GB).
- New rows: Cargo Registry, Bun, uv and Dart Pub caches (safe); Playwright and Puppeteer browsers, Maven repository, Hugging Face models and Xcode Previews (careful).
- VS Code / Cursor and Slack / Discord caches, skipped while that app is open.
- Keyboard control: ⌘R rescan, ⌘⏎ clean, ⌘A / ⇧⌘A select all / none, Tab between rows, Space to select, ← / → for details.
- "Last cleaned …" under Rescan, with a history of recent cleans.
- Help menu (website, report a problem, release notes) and Check for Updates…, which only open pages in your browser.

### Changed
- Your own row choices are remembered across rescans and launches.
- Cleaning removes each item in one pass and counts exactly what left the disk; scans run four at a time. Both are faster on large caches.
- Free RAM now says whether memory was freed, the prompt was cancelled, or it failed.
- Dim text is brighter and easier to read; the app, its alerts and About stay dark in Light Mode.
- Playwright's browsers are now their own careful row instead of part of App Caches.

### Fixed
- Browser Caches no longer reports Safari's cache as a failure after every clean when Full Disk Access is off; the row names the folder that needs it instead.
- A clean that leaves thousands of items behind no longer freezes the failures list.
- Rescan no longer resets the selection.

## [1.0.0] - 2026-11-18

First release: disk cleanup of a fixed list of developer and app caches, and the memory panel with Free RAM.

[1.0.1]: https://github.com/biggypanda/FreeMyMacOS/releases/tag/v1.0.1
[1.0.0]: https://github.com/biggypanda/FreeMyMacOS/releases/tag/v1.0.0
