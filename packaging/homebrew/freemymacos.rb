cask "freemymacos" do
  version "1.0.1"
  sha256 "REPLACE_WITH_SHA256_OF_THE_NOTARIZED_DMG"

  url "https://github.com/biggypanda/FreeMyMacOS/releases/download/v#{version}/FreeMyMacOS.dmg"
  name "FreeMyMacOS"
  desc "Clears developer and app caches and shows what is using memory"
  homepage "https://freemymacos.com/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "FreeMyMacOS.app"

  zap trash: [
    "~/Library/Caches/com.pandacle.freemymacos",
    "~/Library/Preferences/com.pandacle.freemymacos.plist",
    "~/Library/Saved Application State/com.pandacle.freemymacos.savedState",
  ]
end
