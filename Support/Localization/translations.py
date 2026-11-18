# Source of truth for the app's Turkish and German text. English is the key.
# Run `python3 Support/Localization/translations.py` to regenerate the .lproj files.
import os

T = {
# --- Core: failure reasons
"Outside the allowed folders": ("İzin verilen klasörlerin dışında", "Außerhalb der erlaubten Ordner"),
"Is a protected folder": ("Korunan bir klasör", "Geschützter Ordner"),
"Unsafe location": ("Güvenli olmayan konum", "Unsicherer Ort"),
"Permission denied": ("İzin verilmedi", "Zugriff verweigert"),
"Could not read folder": ("Klasör okunamadı", "Ordner konnte nicht gelesen werden"),
"No longer exists": ("Artık yok", "Existiert nicht mehr"),
"Could not delete": ("Silinemedi", "Konnte nicht gelöscht werden"),
"Quit %@ first": ("Önce %@ uygulamasından çık", "Zuerst %@ beenden"),
# --- Catalog titles
"Xcode DerivedData": ("Xcode DerivedData", "Xcode DerivedData"),
"Simulator Caches": ("Simülatör Önbellekleri", "Simulator-Caches"),
"iOS Device Support": ("iOS Device Support", "iOS Device Support"),
"Xcode Archives": ("Xcode Arşivleri", "Xcode-Archive"),
"Xcode Previews": ("Xcode Önizlemeleri", "Xcode-Vorschauen"),
"SwiftPM Cache": ("SwiftPM Önbelleği", "SwiftPM-Cache"),
"npm / Yarn / pnpm": ("npm / Yarn / pnpm", "npm / Yarn / pnpm"),
"pip Cache": ("pip Önbelleği", "pip-Cache"),
"CocoaPods Cache": ("CocoaPods Önbelleği", "CocoaPods-Cache"),
"Gradle Caches": ("Gradle Önbellekleri", "Gradle-Caches"),
"Homebrew Downloads": ("Homebrew İndirmeleri", "Homebrew-Downloads"),
"Cargo Registry": ("Cargo Kayıt Deposu", "Cargo-Registry"),
"Bun Cache": ("Bun Önbelleği", "Bun-Cache"),
"uv Cache": ("uv Önbelleği", "uv-Cache"),
"Dart Pub Cache": ("Dart Pub Önbelleği", "Dart-Pub-Cache"),
"Playwright Browsers": ("Playwright Tarayıcıları", "Playwright-Browser"),
"Puppeteer Browsers": ("Puppeteer Tarayıcıları", "Puppeteer-Browser"),
"Maven Repository": ("Maven Deposu", "Maven-Repository"),
"Hugging Face Models": ("Hugging Face Modelleri", "Hugging-Face-Modelle"),
"VS Code / Cursor Caches": ("VS Code / Cursor Önbellekleri", "VS Code / Cursor-Caches"),
"Browser Caches": ("Tarayıcı Önbellekleri", "Browser-Caches"),
"Slack / Discord Caches": ("Slack / Discord Önbellekleri", "Slack / Discord-Caches"),
"App Caches": ("Uygulama Önbellekleri", "App-Caches"),
"User Logs": ("Kullanıcı Kayıtları", "Benutzerprotokolle"),
"Trash": ("Çöp Sepeti", "Papierkorb"),
# --- Catalog details
"Intermediate build products and indexes that Xcode recreates the next time you build.":
 ("Xcode'un bir sonraki derlemede yeniden oluşturduğu ara derleme ürünleri ve dizinler.",
  "Zwischenprodukte und Indizes, die Xcode beim nächsten Build neu erstellt."),
"Cached data for the iOS Simulator that it rebuilds on demand when it next runs.":
 ("iOS Simülatörü'nün bir sonraki açılışta gerektikçe yeniden oluşturduğu önbellek verileri.",
  "Zwischengespeicherte Daten des iOS-Simulators, die er beim nächsten Start bei Bedarf neu erstellt."),
"Debug symbols copied from connected devices, which Xcode copies again the next time that device is connected.":
 ("Bağlanan cihazlardan kopyalanan hata ayıklama sembolleri; Xcode cihaz yeniden bağlandığında tekrar kopyalar.",
  "Debug-Symbole verbundener Geräte, die Xcode beim nächsten Verbinden des Geräts erneut kopiert."),
"App builds you archived for distribution, worth keeping only if you still need to symbolicate or resubmit them.":
 ("Dağıtım için arşivlediğin uygulama derlemeleri; yalnızca sembolleştirme ya da yeniden gönderme için hâlâ gerekiyorsa sakla.",
  "Für die Verteilung archivierte App-Builds; nur aufheben, wenn du sie noch symbolisieren oder erneut einreichen musst."),
"Builds Xcode made for SwiftUI previews; it rebuilds them, slowly, the next time a preview opens.":
 ("Xcode'un SwiftUI önizlemeleri için yaptığı derlemeler; bir önizleme açıldığında yavaşça yeniden derlenir.",
  "Builds, die Xcode für SwiftUI-Vorschauen erstellt hat; beim nächsten Öffnen einer Vorschau werden sie langsam neu gebaut."),
"Downloaded Swift package sources that SwiftPM fetches again when a project needs them.":
 ("İndirilmiş Swift paket kaynakları; bir proje ihtiyaç duyduğunda SwiftPM yeniden indirir.",
  "Heruntergeladene Swift-Paketquellen, die SwiftPM erneut lädt, wenn ein Projekt sie braucht."),
"Package download caches for JavaScript tools, which are refilled automatically on the next install.":
 ("JavaScript araçlarının paket indirme önbellekleri; bir sonraki kurulumda kendiliğinden dolar.",
  "Paket-Caches von JavaScript-Tools, die sich bei der nächsten Installation automatisch wieder füllen."),
"Downloaded Python packages and wheels that pip fetches again when you next install them.":
 ("İndirilmiş Python paketleri ve wheel dosyaları; bir sonraki kurulumda pip yeniden indirir.",
  "Heruntergeladene Python-Pakete und Wheels, die pip bei der nächsten Installation erneut lädt."),
"Downloaded pod sources that CocoaPods fetches again on the next pod install.":
 ("İndirilmiş pod kaynakları; bir sonraki pod install'da CocoaPods yeniden indirir.",
  "Heruntergeladene Pod-Quellen, die CocoaPods beim nächsten pod install erneut lädt."),
"Downloaded dependencies and build caches that Gradle restores on the next build.":
 ("İndirilmiş bağımlılıklar ve derleme önbellekleri; Gradle bir sonraki derlemede geri getirir.",
  "Heruntergeladene Abhängigkeiten und Build-Caches, die Gradle beim nächsten Build wiederherstellt."),
"Installer files Homebrew already used, which it downloads again only if it needs them.":
 ("Homebrew'un zaten kullandığı kurulum dosyaları; yalnızca gerekirse yeniden indirir.",
  "Bereits genutzte Installationsdateien von Homebrew, die es nur bei Bedarf erneut lädt."),
"Downloaded Rust crates that Cargo fetches again when a project needs them.":
 ("İndirilmiş Rust crate'leri; bir proje ihtiyaç duyduğunda Cargo yeniden indirir.",
  "Heruntergeladene Rust-Crates, die Cargo erneut lädt, wenn ein Projekt sie braucht."),
"Package downloads Bun keeps, which it refills on the next install.":
 ("Bun'ın sakladığı paket indirmeleri; bir sonraki kurulumda yeniden dolar.",
  "Paket-Downloads von Bun, die bei der nächsten Installation wieder geladen werden."),
"Python packages the uv tool downloaded, which it fetches again when needed.":
 ("uv aracının indirdiği Python paketleri; gerektiğinde yeniden indirir.",
  "Python-Pakete, die uv heruntergeladen hat und bei Bedarf erneut lädt."),
"Downloaded Dart and Flutter packages; run pub get in a project to fetch them again.":
 ("İndirilmiş Dart ve Flutter paketleri; yeniden almak için projede pub get çalıştır.",
  "Heruntergeladene Dart- und Flutter-Pakete; mit pub get im Projekt holst du sie zurück."),
"Browser builds Playwright downloaded for tests; run npx playwright install to get them back.":
 ("Playwright'ın testler için indirdiği tarayıcılar; geri almak için npx playwright install çalıştır.",
  "Browser, die Playwright für Tests geladen hat; mit npx playwright install holst du sie zurück."),
"Browser builds Puppeteer downloaded for tests, fetched again on the next install.":
 ("Puppeteer'ın testler için indirdiği tarayıcılar; bir sonraki kurulumda yeniden indirilir.",
  "Browser, die Puppeteer für Tests geladen hat; sie werden bei der nächsten Installation erneut geladen."),
"Downloaded Java libraries; anything you installed locally with mvn install exists only here.":
 ("İndirilmiş Java kütüphaneleri; mvn install ile yerelde kurduğun her şey yalnızca burada durur.",
  "Heruntergeladene Java-Bibliotheken; was du lokal mit mvn install installiert hast, gibt es nur hier."),
"Downloaded AI models, which can be very large and slow to download again.":
 ("İndirilmiş yapay zekâ modelleri; çok büyük olabilir ve yeniden indirmesi uzun sürer.",
  "Heruntergeladene KI-Modelle, die sehr groß sein können und lange zum erneuten Laden brauchen."),
"Caches the editors rebuild on their own. Quit the editor first; while it is open they are skipped.":
 ("Editörlerin kendiliğinden yeniden oluşturduğu önbellekler. Önce editörden çık; açıkken atlanır.",
  "Caches, die die Editoren selbst neu erstellen. Beende zuerst den Editor; solange er offen ist, werden sie übersprungen."),
"Saved copies of web pages and images that browsers download again as you browse.":
 ("Web sayfalarının ve görsellerin kayıtlı kopyaları; gezinirken tarayıcılar yeniden indirir.",
  "Gespeicherte Kopien von Webseiten und Bildern, die Browser beim Surfen erneut laden."),
"Cached images and files the chat apps download again. Quit the app first; while it is open they are skipped.":
 ("Sohbet uygulamalarının yeniden indirdiği önbellekteki görsel ve dosyalar. Önce uygulamadan çık; açıkken atlanır.",
  "Zwischengespeicherte Bilder und Dateien, die die Chat-Apps erneut laden. Beende zuerst die App; solange sie offen ist, werden sie übersprungen."),
"Temporary files apps keep to load faster, which they recreate as they need them.":
 ("Uygulamaların daha hızlı açılmak için tuttuğu geçici dosyalar; gerektikçe yeniden oluşturulur.",
  "Temporäre Dateien, mit denen Apps schneller laden und die sie bei Bedarf neu erstellen."),
"Diagnostic log files written by apps, which they start fresh when needed.":
 ("Uygulamaların yazdığı tanılama kayıtları; gerektiğinde sıfırdan başlar.",
  "Diagnoseprotokolle von Apps, die bei Bedarf neu beginnen."),
"Items you already moved to the Trash, which are removed for good when it is emptied.":
 ("Çöp Sepeti'ne zaten taşıdığın öğeler; sepet boşaltılınca kalıcı olarak silinir.",
  "Objekte, die du schon in den Papierkorb gelegt hast; beim Entleeren werden sie endgültig gelöscht."),
# --- Menus
"Check for Updates…": ("Güncellemeleri Denetle…", "Nach Updates suchen …"),
"Clean": ("Temizle", "Bereinigen"),
"Rescan": ("Yeniden Tara", "Erneut scannen"),
"Clean Selected": ("Seçilenleri Temizle", "Auswahl bereinigen"),
"Select All": ("Tümünü Seç", "Alle auswählen"),
"Select None": ("Hiçbirini Seçme", "Keine auswählen"),
"%@ Website": ("%@ Web Sitesi", "%@-Website"),
"Report a Problem…": ("Sorun Bildir…", "Problem melden …"),
"Release Notes": ("Sürüm Notları", "Versionshinweise"),
# --- Window
"Clean items marked Review first?": ("“Önce incele” işaretli öğeler temizlensin mi?", "Mit „Erst prüfen“ markierte Objekte bereinigen?"),
"Cancel": ("Vazgeç", "Abbrechen"),
"%@ will be removed for good. This can't be undone.": ("%@ kalıcı olarak silinecek. Bu geri alınamaz.", "%@ wird endgültig entfernt. Das lässt sich nicht widerrufen."),
"Developer": ("Geliştirici", "Entwicklung"),
"Browsers": ("Tarayıcılar", "Browser"),
"Apps": ("Uygulamalar", "Apps"),
"System": ("Sistem", "System"),
# --- Hero
"Last cleaned %@ · %@": ("Son temizlik: %@ · %@", "Zuletzt bereinigt: %@ · %@"),
"Would free %@": ("%@ boşalırdı", "Würde %@ freigeben"),
"Freed %@": ("%@ boşaltıldı", "%@ freigegeben"),
"%@ found so far": ("%@ bulundu", "%@ bisher gefunden"),
"Looking around": ("Göz atılıyor", "Wird durchsucht"),
"Clearing": ("Temizleniyor", "Wird bereinigt"),
"%@ can go": ("%@ silinebilir", "%@ können weg"),
"Nothing selected": ("Hiçbir şey seçilmedi", "Nichts ausgewählt"),
"Scanning": ("Taranıyor", "Scannen"),
"Cleaning": ("Temizleniyor", "Bereinigen"),
"Done": ("Bitti", "Fertig"),
"Clean %@": ("%@ Temizle", "%@ bereinigen"),
"Couldn't be removed": ("Silinemeyenler", "Nicht entfernt"),
"and %lld more": ("ve %lld tane daha", "und %lld weitere"),
"Recent cleans": ("Son temizlikler", "Letzte Bereinigungen"),
"1 item couldn't be removed": ("1 öğe silinemedi", "1 Objekt konnte nicht entfernt werden"),
"%lld items couldn't be removed": ("%lld öğe silinemedi", "%lld Objekte konnten nicht entfernt werden"),
# --- Memory
"Memory": ("Bellek", "Speicher"),
"Memory, %@": ("Bellek, %@", "Speicher, %@"),
"Shows the apps using the most memory": ("En çok bellek kullanan uygulamaları gösterir", "Zeigt die Apps mit dem größten Speicherbedarf"),
"Asks for your administrator password, then runs purge": ("Yönetici parolanı sorar, ardından purge çalıştırır", "Fragt nach deinem Administratorpasswort und führt dann purge aus"),
"Asks for your administrator password": ("Yönetici parolanı sorar", "Fragt nach deinem Administratorpasswort"),
"Freeing…": ("Boşaltılıyor…", "Wird freigegeben …"),
"Free RAM": ("RAM Boşalt", "RAM freigeben"),
"Memory freed": ("Bellek boşaltıldı", "Speicher freigegeben"),
"Cancelled": ("Vazgeçildi", "Abgebrochen"),
"Couldn't free memory": ("Bellek boşaltılamadı", "Speicher nicht freigegeben"),
"Unavailable": ("Kullanılamıyor", "Nicht verfügbar"),
"%@ of %@ GB": ("%@ / %@ GB", "%@ von %@ GB"),
"Using the most memory": ("En çok bellek kullananlar", "Größter Speicherbedarf"),
"No apps to show": ("Gösterilecek uygulama yok", "Keine Apps"),
"Quit": ("Çık", "Beenden"),
"Quit %@": ("%@ uygulamasından çık", "%@ beenden"),
# --- Rows
"Some of these folders need Full Disk Access": ("Bu klasörlerin bazıları Tam Disk Erişimi istiyor", "Einige dieser Ordner brauchen Festplattenvollzugriff"),
"Some folders need Full Disk Access": ("Bazı klasörler Tam Disk Erişimi istiyor", "Einige Ordner brauchen Festplattenvollzugriff"),
"Review first": ("Önce incele", "Erst prüfen"),
"Select %@": ("%@ seç", "%@ auswählen"),
"Hide details": ("Ayrıntıları gizle", "Details ausblenden"),
"Show details": ("Ayrıntıları göster", "Details einblenden"),
"Grant access": ("Erişim ver", "Zugriff erlauben"),
"Reading this folder needs Full Disk Access. Turn it on for %@ in Privacy settings, then rescan.":
 ("Bu klasörü okumak için Tam Disk Erişimi gerekiyor. Gizlilik ayarlarından %@ için aç, sonra yeniden tara.",
  "Zum Lesen dieses Ordners ist Festplattenvollzugriff nötig. Aktiviere ihn für %@ in den Datenschutzeinstellungen und scanne dann erneut."),
"Open Privacy settings": ("Gizlilik ayarlarını aç", "Datenschutzeinstellungen öffnen"),
"%@ needs Full Disk Access, so it is not counted.": ("%@ Tam Disk Erişimi istiyor, bu yüzden sayılmadı.", "%@ braucht Festplattenvollzugriff und wird daher nicht mitgezählt."),
"%@ need Full Disk Access, so they are not counted.": ("%@ Tam Disk Erişimi istiyor, bu yüzden sayılmadı.", "%@ brauchen Festplattenvollzugriff und werden daher nicht mitgezählt."),
"Show in Finder": ("Finder'da göster", "Im Finder zeigen"),
}

def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')

here = os.path.dirname(os.path.abspath(__file__))
for index, lang in enumerate(["tr", "de"]):
    folder = os.path.join(here, f"{lang}.lproj")
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, "Localizable.strings"), "w", encoding="utf-8") as f:
        f.write("/* Generated by translations.py. Edit that file, not this one. */\n\n")
        for key, values in T.items():
            f.write(f'"{esc(key)}" = "{esc(values[index])}";\n')
# English is the development language: the keys are the text.
folder = os.path.join(here, "en.lproj")
os.makedirs(folder, exist_ok=True)
with open(os.path.join(folder, "Localizable.strings"), "w", encoding="utf-8") as f:
    f.write("/* English is the development language: every key is its own text. */\n")
print(f"{len(T)} keys")
