# Homebrew tap

`freemymacos.rb` is the cask for the personal tap at `biggypanda/homebrew-tap`
(installed with `brew trust biggypanda/tap` once, then `brew install --cask biggypanda/tap/freemymacos`).

For each release:

1. Set `version` and `sha256` (`shasum -a 256 dist/FreeMyMacOS.dmg`).
2. Copy the file to `Casks/freemymacos.rb` in the `homebrew-tap` repository and push.
3. Check it with `brew audit --cask --strict biggypanda/tap/freemymacos` and `brew install --cask biggypanda/tap/freemymacos`.
