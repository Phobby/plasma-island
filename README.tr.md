<!-- Bu dosyada hâlâ açık olanlar docs/RELEASE-CHECKLIST.md içinde listelidir: ana video, henüz kaydedilmemiş klipler, yol haritası. -->

# KDE Plasma 6 için Dinamik Ada

Ekranın üst ortasında duran, o an ne olup bittiğini (müzik, zamanlayıcı, indirme, arama, bildirim) gösteren ve imleç üzerine gelince sayfalara açılan bir hap.

[![Lisans: GPL-2.0-or-later](https://img.shields.io/badge/licence-GPL--2.0--or--later-blue.svg)](#lisans-ve-teşekkürler)
![Sürüm 0.1.0](https://img.shields.io/badge/version-0.1.0-informational.svg)
![Plasma 6](https://img.shields.io/badge/Plasma-6-1d99f3.svg)

[English](README.md) · **Türkçe**

<!-- TODO(owner): hero video / GIF here -->

Klipler arayüz İngilizceyken kaydedilmiştir; ada Türkçe de konuşur (Ayarlar → Dil).

## İçindekiler

- [Nedir](#nedir)
- [Gereksinimler](#gereksinimler)
- [Kurulum, güncelleme, kaldırma](#kurulum-güncelleme-kaldırma)
- [İlk adımlar](#i̇lk-adımlar)
- [Adanın durumları](#adanın-durumları)
- [Sayfalar](#sayfalar): [Etkinlikler](#etkinlikler) · [Medya](#medya) · [Sistem](#sistem) · [Hava Durumu](#hava-durumu) · [Bildirimler](#bildirimler) · [Kontroller](#kontroller) · [Uygulamalar](#uygulamalar) · [Araçlar](#araçlar) · [Alışkanlıklar](#alışkanlıklar) · [Takvim](#takvim) · [Notlar](#notlar) · [Yapay Zeka](#yapay-zeka) · [Bulut](#bulut) · [Pano](#pano)
- [İndirmeler ve dosya aktarımları](#i̇ndirmeler-ve-dosya-aktarımları)
- [Öneriler](#öneriler)
- [Kedi](#kedi)
- [Görünüm, temalar ve mağaza](#görünüm-temalar-ve-mağaza)
- [Düzen ve dil](#düzen-ve-dil)
- [Geliştiriciler için: kendi etkinliğini gönder](#geliştiriciler-için-kendi-etkinliğini-gönder)
- [Performans](#performans)
- [Gizlilik ve ağ](#gizlilik-ve-ağ)
- [Sorun giderme](#sorun-giderme)
- [Bilinen sınırlar](#bilinen-sınırlar)
- [Katkı, güvenlik, lisans](#katkı-ve-güvenlik)

## Nedir

| | |
|---|---|
| **Canlı etkinlikler** | Küçük hap, o an süren en önemli şeyi gösterir: kapağıyla müzik, zamanlayıcı, ilerlemesiyle bir aktarım, ekran kaydı, arama. İki şey aynı anda sürüyorsa ada ikiye ayrılır. |
| **Anlık olaylar** | Ses, parlaklık, şarj, Bluetooth, Caps Lock, yeni bildirim: birkaç saniye gösterilir, sonra ada eski haline döner. |
| **Sayfalar** | Üzerine gelince ada açılır: Medya, Sistem, Hava Durumu, Bildirimler, Kontroller, Uygulamalar, Araçlar, Alışkanlıklar, Takvim, Notlar, Pano ve (siz açana kadar kapalı) Yapay Zeka ile Bulut. |
| **Yoldan çekilir** | Bir tıklama onu noktaya küçültür; adanın yanındaki tıklamalar alttaki pencereye gider. |
| **Sizin görünümünüz** | Plasma'nın renklerini izler ya da sizin belirlediğiniz görünümü taşır: renkler ya da gradyan, opaklık, bulanıklık, köşe yuvarlaklığı. Görünümler dosya olarak dışa aktarılabilir. |
| **Betiklenebilir** | Her program küçük bir D-Bus API'siyle (`island-push`) kendi etkinliğini gösterebilir. |
| **Varsayılan olarak gizli** | Telemetri yok. Hava durumu için bir konum seçene, bir takvim ya da not uygulaması bağlayana, Yapay Zeka ya da Bulut'u açana kadar ağdan hiçbir şey istenmez. Bkz. [Gizlilik ve ağ](#gizlilik-ve-ağ). |

QML ile yazılmış bir Plasma widget'ıdır (plasmoid); QML'in erişemediği kısımlar için isteğe bağlı küçük bir yerel modül (C++) vardır. Her parça isteğe bağlıdır ve kapatılabilir.

## Gereksinimler

| | |
|---|---|
| Masaüstü | KDE Plasma 6 (widget en düşük Plasma API 6.0 bildirir) |
| Test edildiği ortam | Kubuntu 26.04, Plasma 6.6.6, Qt 6.10.2, **Wayland** üzerinde KWin, NVIDIA sürücüsü. Başka hiçbir ortam denenmedi. |
| X11 | **Denenmedi.** Tıklama geçirme bölgesi ikisi için de yazıldı ama yalnızca Wayland'de denendi (bkz. [Bilinen sınırlar](#bilinen-sınırlar)). |
| Yerel modülü derlemek için | `cmake`, `extra-cmake-modules`, Qt 6.5 ya da daha yeni geliştirme dosyaları (Core, Gui, Qml, DBus, Network, Sql), `libkf6windowsystem-dev` |
| Çalışma zamanında | Mikrofon, kamera ve ekran kaydı göstergeleri için PipeWire'ın `pw-dump` aracı (Ubuntu'da `pipewire-bin` paketi) |

Yerel modül olmadan widget yine çalışır; ona ihtiyaç duyan kısımlar kendini gizler: biçimli bulanıklık, adanın yanındaki tıklamaların alttaki pencereye geçmesi, kayıt, mikrofon ve kamera göstergeleri, kilit açma, KDE Connect aramaları, güncelleme sayısı, D-Bus API'si, takvim hesapları ve tüm parola ve anahtarlar (KDE Cüzdan'da durur), tema dosyaları, indirme takibi, Bulut ve Yapay Zeka yardımcıları.

**İsteğe bağlı programlar.** Hiçbiri zorunlu değil; her biri bir şey ekler.

| Program | Ne ekler |
|---|---|
| [rclone](https://rclone.org) | Bulut sayfası: rclone uzaklarınız (Google Drive, OneDrive, Dropbox, WebDAV…) |
| [BetterNotes](https://github.com/thebanri/BetterNotes) 0.1.13+ | Bu bilgisayarda, hesapsız notlar (bir notu uygulamada açmak için 0.1.14, kilitli notlar için 0.1.15) |
| Joplin (masaüstü), bir Simplenote hesabı, bir Memos sunucusu | Notlar sayfasında onların notları |
| KDE Connect | Telefon pili, aramalar, telefondan gelen bildirimler, "telefonumu bul" |
| Claude Code (`claude`), Antigravity (`agy`) | Yapay Zeka sayfası bunlar üzerinden, tüm araçları kapalı olarak yanıt verir |
| Ollama, LM Studio, llama.cpp, Jan, KoboldCpp | Yapay Zeka sayfası bu bilgisayardaki bir modelden yanıt verir |
| `btop` 1.4+ | Bir Sistem kartına tıklamak o ölçünün grafiğini uçbirimde açar |
| Spectacle, Discover, bir kamera uygulaması | Kontroller sayfasındaki ilgili düğmeler |
| PackageKit | Bekleyen güncelleme sayısı |

## Kurulum, güncelleme, kaldırma

```bash
git clone https://github.com/Phobby/plasma-island.git
cd plasma-island
./install.sh               # widget, yerel modül ve island-push
systemctl --user restart plasma-plasmashell
```

Ya da hepsi, kopyalayıp yapıştırılacak tek satır olarak:

```bash
git clone https://github.com/Phobby/plasma-island.git && cd plasma-island && ./install.sh && systemctl --user restart plasma-plasmashell
```

`install.sh` parola istemez ve hiçbir şey indirmez: widget'ı `kpackagetool6` ile kullanıcınıza kurar, yerel modülü CMake ile derleyip `~/.local/lib/qml` altına koyar, `island-push` aracını `~/.local/bin` altına koyar ve modülü plasmashell'e görünür kılar (`~/.config/environment.d/90-dynamicisland.conf` içinde `QML_IMPORT_PATH`). Yeniden çalıştırmak yerinde günceller.

| | |
|---|---|
| Yalnızca widget, yerel modül olmadan | `./install.sh --no-native` |
| Elle | `kpackagetool6 -t Plasma/Applet -i org.phobby.dynamicisland` (güncellemek için `-u`) |
| Güncelleme | `git pull`, sonra `./install.sh` ve plasmashell'i yeniden başlatın |
| Kaldırma | `./install.sh --remove`, sonra plasmashell'i yeniden başlatın |

Kaldırma verilerinizi yerinde bırakır: `~/.local/share/dynamicisland/` (eklediğiniz temalar, önerilerin öğrendikleri, saklanan Yapay Zeka sohbeti), `~/.cache/dynamicisland/` (buluttan alınan dosyalar), KDE Cüzdan'daki "Dynamic Island" klasörü ve widget'ı masaüstünden kaldırana kadar Plasma'nın kendi dosyasındaki ayarları. Gitmesini istiyorsanız elle silin.

**Ekrana yerleştirme.** Ada kendi başına bir penceredir, bu yüzden widget'ın nereye eklendiği önemli değildir:

1. Masaüstüne (ya da düzenleme kipindeki bir panele) sağ tıklayın → araç takımı (widget) ekleme penceresini açın (*Araç Takımları Ekle…*) → "Dinamik Ada".
2. Orada küçük bir tutamaç simgesi belirir; adanın kendisi o ekranın üst ortasında durur.
3. Üstte bir panel varsa ada hemen altına yerleşir. Ayarlar → Genel → *Üst panellerin altına yerleş* kapatılırsa ada panelin üzerine (çentik gibi) oturur; o zaman *Üstten uzaklık* değerini ayarlayın.

Plasma'nın kendi ses açılır penceresi adanınkinin yanında görünmeye devam eder. Yalnızca birini bırakmak için: adada Ayarlar → Etkinlikler → "Ses, parlaklık ve ses çıkışı" seçeneğini kapatın ya da Sistem Ayarları → Ses içinden ses açılır pencerelerini kapatın. (Plasma'da parlaklık açılır penceresini kapatan bir ayar yok.)

## İlk adımlar

- Hapın **üzerine gelin**: açılır. Uzaklaşın: kapanır (0,4 sn sonra; iki gecikme de Ayarlar → Genel içindedir).
- Üstteki **sekmeler** sayfa değiştirir; liste olmayan her yerde fare tekerleği ya da iki parmakla kaydırma da öyle.
- Küçük hapa **tıklayın**: noktaya küçülür. Noktaya tıklayın: hap geri gelir. ([Nokta modu](#nokta-modu) kapatılabilir.)
- Menüsü için adaya **sağ tıklayın**; açık adanın sağ üstündeki dişli ayarları açar.
- **Ayarlar → Düzen** sayfaları gösterir, gizler ve sıralar. Yapay Zeka ve Bulut orada açılana kadar kapalıdır.
- **Dil**: sistem Türkçe ise ada Türkçe, değilse İngilizce konuşur; Ayarlar → Dil bunu anında değiştirir.

## Adanın durumları

<!-- GIF: island-states.gif | Küçük hap saati, sonra göndereni ve ilk satırıyla bir bildirimi, sonra "Bitti" ile sonlanan ilerleme halkalı bir etkinliği gösteriyor. | Küçük adanın durumları -->
<p align="center"><img src="docs/media/island-states.gif" alt="Küçük hap saati, sonra göndereni ve ilk satırıyla bir bildirimi, sonra &quot;Bitti&quot; ile sonlanan ilerleme halkalı bir etkinliği gösteriyor." width="800"><br><sub>Küçük adanın durumları</sub></p>

| Durum | Ne zaman | Ne görürsünüz |
|---|---|---|
| Boşta | Hiçbir şey olmuyor | Saatli küçük bir hap |
| Canlı etkinlik | Bir şey sürüyor (müzik, zamanlayıcı, aktarım, kayıt, arama) | Solda simgesi ya da kapağı, sağda süresi, değeri ya da ilerleme halkası |
| Ayrık | İki şey aynı anda sürüyor | İlki hapta, ikincisi yanındaki dairede |
| Bildirim | Bir bildirim geldiğinde | Uygulama, başlık, ilk satır. Tıklama varsayılan eylemi çalıştırır, orta tıklama kapatır |
| Anlık olay | Ses, parlaklık, şarj, Bluetooth, Caps Lock, Wi-Fi… | 2–4 sn boyunca geniş bir hap |
| Öneri | Bir kuralın anı (bkz. [Öneriler](#öneriler)) | Bir cümle ve düğme olarak yanıtları |
| Açık | Üzerine gelme ya da tıklama | Aşağıdaki sayfalar |
| Gizlilik noktaları | Mikrofon ya da kamera kullanımda | Adanın yanında, her durumda turuncu ya da yeşil bir nokta |
| Nokta | Nokta modunda bir tıklamadan sonra | Hapın yerinde küçük bir daire |

Birden fazla şey sürerken hangisinin öne geçeceği yeniden sıralayabileceğiniz bir listedir (Ayarlar → Etkinlikler): gizlilik, arama, ekran kaydı, anlık olaylar, zamanlayıcı, aktarımlar, medya.

### Nokta modu

<!-- GIF: dot-mode.gif | Bir tıklama hapı noktaya küçültüyor; noktanın yanındaki bir pencereye tıklanıyor; noktaya tıklamak hapı geri getiriyor. | Nokta modu -->

Küçük hapa tıklamak onu yoldan çekilsin diye bir noktaya çevirir (15 px, ayarlarda 10–28); noktaya tıklamak hapı geri getirir. Noktanın ortası ne olduğunu söyler: mikrofon, kamera ya da ekran kullanımı için turuncu, yeşil ya da kırmızı; canlı etkinlik (nabız gibi atar) ya da bekleyen bildirimler için vurgu rengi. Nokta halindeyken bildirimler ve olaylar saklanır ve hap geri gelince gösterilir (ya da hemen gösterilip noktaya dönülür: *Nokta modunda olaylar*). Gelen arama, alarm ve düşük pil, siz kapatmadıkça her durumda adayı açar.

**Ayarlar → Genel → Nokta modu:** açık/kapalı, başlangıç durumu (bırakıldığı gibi, her zaman hap, her zaman nokta), nokta boyutu, üzerine gelince açılıp açılmayacağı, nokta modunda olaylar, kritik olaylarda her zaman genişleme.

## Sayfalar

### Etkinlikler

*O an süren her şey, düğmeleriyle.* Sayfa yalnızca bir şey sürerken görünür.

<!-- GIF: activities-page.gif | Açık ada Etkinlikler sayfasında: çalışan bir zamanlayıcı ve bir indirme, her biri kendi düğmeleriyle. | Etkinlikler sayfası -->

- **Ne görürsünüz:** süren her etkinlik için bir kart (zamanlayıcı, aktarım, kayıt, arama, medya…), eylemleriyle; mikrofonu ya da kamerayı hangi uygulamanın kullandığı.
- **Nasıl kullanılır:** karttaki düğmeler o etkinliğe uygulanır (zamanlayıcıyı duraklatmak, biten indirmenin klasörünü açmak, kayıt yapan uygulamaya geçmek).
- **Ayarlar:** Ayarlar → Etkinlikler: öncelik sırası, ayrık ada, anlık olayın ne kadar kalacağı ve her olay ve etkinlik türü için bir anahtar.

### Medya

*Ne çalıyor ve denetimleri.*

<!-- GIF: media-controls.gif | Hap bir kapak, parçanın adını ve bir ekolayzer gösteriyor; sonraki parça geliyor; duraklatılıp yeniden çalınıyor. | Hapta medya: parça değişimi, duraklat ve çal -->
<p align="center"><img src="docs/media/media-controls.gif" alt="Hap bir kapak, parçanın adını ve bir ekolayzer gösteriyor; sonraki parça geliyor; duraklatılıp yeniden çalınıyor." width="800"><br><sub>Hapta medya: parça değişimi, duraklat ve çal</sub></p>
<!-- GIF: media-page.gif | Açık Medya sayfası: kapak, başlık ve sanatçı, önceki, çal ve sonraki, konum sürükleniyor. | Medya: sayfa ve denetimleri -->
<!-- GIF: media-glow.gif | Müzik çalarken hapın kenarı kapağın renginde parlamaya ve müzikle hareket etmeye başlıyor; sonra ışık yeniden kapatılıyor. | Medya: ortam ışığı -->
<p align="center"><img src="docs/media/media-glow.gif" alt="Müzik çalarken hapın kenarı kapağın renginde parlamaya ve müzikle hareket etmeye başlıyor; sonra ışık yeniden kapatılıyor." width="800"><br><sub>Medya: ortam ışığı</sub></p>
<!-- GIF: media-cat.gif | Hapın yanındaki kedi müzik çalarken kulaklık takıp kafasını sallıyor. | Medya: kedi de dinliyor -->
<p align="center"><img src="docs/media/media-cat.gif" alt="Hapın yanındaki kedi müzik çalarken kulaklık takıp kafasını sallıyor." width="800"><br><sub>Medya: kedi de dinliyor</sub></p>

- **Ne görürsünüz:** hapta kapak, parçanın adı ve bir ekolayzer; sayfada kapak, başlık, sanatçı, konum, önceki / çal / sonraki.
- **Nasıl kullanılır:** düğmeler ve konum çubuğu oynatıcıyı yönetir. Sağ üstteki dalga düğmesi **ortam ışığını** açıp kapatır: adanın kenarı kapağın rengini alır, müziğin yüksekliği ve basıyla hareket eder.
- **Ayarlar:** Ayarlar → Genel → *Tercih edilen oynatıcı* (örneğin `spotify`: başka ne çalarsa çalsın o çalıyorsa o gösterilir). Işık varsayılan olarak kapalıdır.
- **Gereksinim ve sınırlar:** MPRIS konuşan her oynatıcı (çoğu konuşur, tarayıcılar da). Işık müziği yalnızca yerel modülle izler (bir şey çalarken çıkışı `pw-record` ile dinler); onsuz yalnızca rengi alır.

### Sistem

*Bilgisayar ne kadar meşgul.* Yalnızca bilgi.

<!-- GIF: system-cards.gif | Sistem sayfası: CPU, sıcaklık, GPU, bellek, ağ ve disk kartları; imlecin altındaki kart büyüyüp ayrıntı gösteriyor. | Sistem: kartlar -->

- **Ne görürsünüz:** CPU, CPU sıcaklığı, GPU, bellek, pil, ağ indirme/yükleme ve disk kartları. *Dinamik* görünümde en meşgul kartlar daha büyüktür; *Sabit* görünümde her kart yerinde kalır.
- **Nasıl kullanılır:** imlecin altındaki kart büyür ve ayrıntılarını gösterir (ağ kartı etkin bağlantının adını verir). Tıklama, o ölçünün grafiğiyle `btop`'u uçbiriminizde açar.
- **Ayarlar:** Ayarlar → Genel → *Sistem görünümü* (Sabit / Dinamik). Ayarlar → Uyarılar: pil, aygıt pili ve sıcaklık eşikleri.
- **Gereksinim ve sınırlar:** değerler Plasma'nın algılayıcı servisinden (ksystemstats) gelir; çalışmıyorsa ada onu başlatır. Sürücünün sunmadığı bir algılayıcının kartı gizlenir. Tıklama için yerel modül ve `btop` 1.4 ya da daha yenisi gerekir.

### Hava Durumu

*Seçtiğiniz bir yer için şu an ve önümüzdeki yedi gün.*

<!-- GIF: weather-location.gif | Hava Durumu sayfası "Konum Seç" ile boş başlıyor; bir şehir yazılıp seçiliyor; tahmin beliriyor; bir güne tıklanınca saatleri kayarak geliyor. | Hava Durumu: yer seçme, bir günün saatleri -->

- **Ne görürsünüz:** şu anki sıcaklık, hissedilen, nem ve rüzgar; en yüksek, en düşük ve yağış olasılığıyla yedi gün; sekmenin kendisi havanın resmini gösterir.
- **Nasıl kullanılır:** boş başlar: *Konum Seç*, bir şehir yazın, seçin. Bir güne tıklamak saatlerini gösterir; ok geri döner. Yerin adı aramayı yeniden açar.
- **Ayarlar:** Ayarlar → Hava Durumu: yer (ara, unut), birimler (°C, km/sa, mm ya da °F, mph, in), yağmur, kar ve fırtına uyarısı.
- **Gereksinim ve sınırlar:** veriler [Open-Meteo](https://open-meteo.com)'nundur. Konum asla algılanmaz ve siz bir yer seçene kadar hiçbir şey istenmez.

### Bildirimler

*Son bildirimler, yanıtla ve kapat ile.*

<!-- GIF: notifications-page.gif | Bildirimler hapa geliyor; Bildirimler sayfası son üçünü saatleriyle listeliyor; "Tümünü temizle" bir kez sorup listeyi boşaltıyor. | Bildirimler -->

- **Ne görürsünüz:** yeni bir bildirim birkaç saniye hapta (uygulama, başlık, ilk satır); sayfada son üç bildirim, geliş saatleriyle.
- **Nasıl kullanılır:** hapta tıklama bildirimin varsayılan eylemini çalıştırır, orta tıklama kapatır. Sayfada, imlecin altında: hızlı yanıt (bildirim sunuyorsa) ve kapat; *Tümünü temizle* bir kez sorar.
- **Ayarlar:** Ayarlar → Genel: gelen bildirimleri göster, ne kadar süre. Rahatsız Etmeyin açıkken bekletilir ve sayılır.
- **Gereksinim ve sınırlar:** Plasma'nın kendi bildirim pencereleri kalır: ada bildirimleri bunlara ek olarak gösterir (Sistem Ayarları → Bildirimler içinden başka bir köşeye taşınabilirler).

### Kontroller

*Telefondaki gibi hızlı ayarlar.*

<!-- GIF: controls-tiles.gif | Kontroller sayfası: Rahatsız Etmeyin ve karanlık mod açılıp kapatılıyor, ses kaydırıcısı oynatılıyor; bir düğmeyi basılı tutmak düzenleme için onları titretiyor. | Kontroller: düğmeler ve kaydırıcılar -->

- **Ne görürsünüz:** seçtiğiniz en fazla altı düğme ve altında ses ile ekran parlaklığı kaydırıcıları.
- **Nasıl kullanılır:** tıklama bir düğmeyi açıp kapatır. Birini basılı tutmak takımı düzenler (taşımak için sürükle, kaldırmak için "−", alttaki sıradan ekle, *Bitti*). **Bluetooth**, **Wi-Fi** ya da **VPN**'i basılı tutmak ise aygıtlarını ya da ağlarını açar.
- **Kullanılabilir düğmeler:** Rahatsız Etmeyin, Gece Işığı, güç profili, Bluetooth, Wi-Fi, güncellemeler, uçak modu, VPN, erişim noktası, ekran kaydı, ekran görüntüsü, kamera, mikrofon, ses, KDE Connect, telefonu bul, karanlık mod, uyanık tut, kilitle, hesap makinesi, Sistem Ayarları. Parçası eksik olan düğme soluk görünür.
- **Ayarlar:** Ayarlar → Kontroller: aynı altı düğme, sırasıyla. Ayarlar → Düzen → Modüller: ses kaydırıcısı.
- **Gereksinim ve sınırlar:** parlaklık kaydırıcısı Plasma'nın kısabildiği bir ekran ister. Program başlatan düğmeler (ekran görüntüsü, hesap makinesi, kilitle…) yerel modül ister.

### Uygulamalar

*Seçtiğiniz uygulamalara kısayollar.*

<!-- GIF: apps-grid.gif | Uygulamalar sayfası: "Ekle" kurulu uygulamaları listeliyor, biri ekleniyor; tıklama onu başlatıyor; iki simge sürüklenerek yer değiştiriyor. | Uygulamalar: ekle, başlat, sırala -->

- **Ne görürsünüz:** en fazla 12 simgelik bir ızgara; birinin altındaki nokta açık bir penceresi olduğunu gösterir.
- **Nasıl kullanılır:** *Ekle* kurulu uygulamaları aramayla listeler. Tıklama uygulamayı başlatır ve adayı kapatır; sağ tıklama yeniden adlandırır ya da kaldırır; sürükleme sıralar.

### Araçlar

*Zamanlayıcı, kronometre, Pomodoro ve alarm.*

<!-- GIF: tools-timer.gif | Bir dakikalık zamanlayıcı başlatılıyor; ada kapanıyor ve hap geri sayıyor; kronometre tur alıyor; Pomodoro istatistikleri gösteriliyor. | Araçlar: zamanlayıcı, kronometre, Pomodoro -->

- **Ne görürsünüz:** tek sayfada dört araç; hangisi çalışıyorsa hapta canlı etkinlik olarak görünür.
- **Nasıl kullanılır:** ayarlayın ve başlatın. Pomodoro turlarını sayar (odak, kısa mola, uzun mola) ve istatistik tutar: bugün, bu hafta, seri, toplam.
- **Ayarlar:** Ayarlar → Araçlar: ses (herhangi bir dosya), Pomodoro süreleri ve tur sayısı, istatistikleri sıfırlama.
- **Sınırlar:** bitiş zamanları saklanır; plasmashell yeniden başlasa da zamanlayıcı kaldığı yerden sürer.

### Alışkanlıklar

*Günlük bir kontrol listesi, akşam değerlendirmesi ve günlerin nasıl geçtiğini gösteren bir takvim.*

<!-- GIF: habits-checklist.gif | Bugünün listesinde alışkanlıklar işaretleniyor; akşamki "Bugün nasıl geçti?" sorusu değerlendirmeyi açıyor; takvim günleri katkı grafiği gibi boyuyor. | Alışkanlıklar: işaretleme, akşam değerlendirmesi, takvim -->

- **Ne görürsünüz:** bugünün listesi; her günü ne kadar yapıldığına göre boyayan bir takvim (haftalar, aylar, yıl).
- **Nasıl kullanılır:** ilk seferde alışkanlıklarınızı ve değerlendirme saatini sorar. Gün içinde tıklama bir maddeyi işaretler. Akşam ada "Bugün nasıl geçti?" diye sorar: *Değerlendir* günün üzerinden ve yarın için eklenecekler üzerinden geçer.
- **Ayarlar:** Ayarlar → Alışkanlıklar: alışkanlıklar (yeniden adlandır, sil, sırala), değerlendirme saati (21:30), hatırlatması, takvimin renkleri, tüm veriyi sıfırlama.
- **Sınırlar:** her şey bu bilgisayarda, widget'ın ayarlarında kalır.

### Takvim

*Takvimlerinizin etkinlikleri ve bir sonrakinin başlamadan önce adaya pinlenmesi.*

<!-- GIF: calendar-connect.gif | Takvim sayfasındaki dişli "Takvim Bağla"yı açıyor: Google ya da Apple seçiliyor, bir bağlantı yapıştırılıyor, ay etkinliklerle doluyor. | Takvim: bir takvim bağlama -->
<!-- GIF: calendar-pinned.gif | Haptaki etkinlik son saniyelerini sayıyor, odası ve Katıl düğmesiyle "başladı"ya dönüyor, sonra kalan süreyi gösteriyor. | Takvim: adadaki sonraki etkinlik -->
<p align="center"><img src="docs/media/calendar-pinned.gif" alt="Haptaki etkinlik son saniyelerini sayıyor, odası ve Katıl düğmesiyle &quot;başladı&quot;ya dönüyor, sonra kalan süreyi gösteriyor." width="800"><br><sub>Takvim: adadaki sonraki etkinlik</sub></p>

- **Ne görürsünüz:** bir ay, seçilen günün etkinlikleri ve ayrıntıları (yer, notlar, toplantı bağlantısı). Bir etkinlik başlamadan 15 dakika önce geri sayımla hapa pinlenir; başlangıçta bir ses çalar ve bitişten sonra 10 dakika kalır.
- **Nasıl kullanılır:** dişli → *Takvim Bağla* → Google ya da Apple → ya takvimin özel `.ics` bağlantısını yapıştırın (salt okunur) ya da hesabı bağlayın (o zaman adadan etkinlik eklenip silinebilir).
- **Ayarlar:** Ayarlar → Takvim: önceki ve sonraki dakikalar, tüm gün süren etkinlikler, bağlantıların ne sıklıkla alınacağı (5 dakika), ses, bağlı takvimler.
- **Gereksinim ve sınırlar:** Akonadi ya da KDE PIM gerekmez. iCloud hesabı uygulamaya özel parola ister; Google hesabı, Google Cloud Console'da bir kez oluşturacağınız kendi OAuth istemcinizi ister (sayfa adım adım anlatır). Parolalar ve belirteçler KDE Cüzdan'da tutulur. Bağlantılar belirli aralıklarla yoklanır; yeni bir etkinlik en geç bir aralık sonra görünür; var olan bir etkinlik düzenlenemez.

### Notlar

*Hızlı bir not ve kullandığınız uygulamaların notları.*

<!-- GIF: notes-quick.gif | Notlar sayfasında bir kaynak seçiliyor, başlıkla bir not oluşturulup içi dolduruluyor; listede beliriyor. | Notlar: not oluşturma -->
<!-- GIF: notes-locked.gif | Kilitli bir BetterNotes notu adada ana parolayı soruyor, sonra metnini gösteriyor. | Notlar: kilitli not -->

- **Ne görürsünüz:** bağlı her uygulamanın notlarından oluşan, en yenisi üstte tek bir liste ve hızlı not için bir alan.
- **Nasıl kullanılır:** yazıp Enter'a basın: varsayılan uygulamada hızlı not; büyüteç arar; tıklama notu düzenlemek için açar (yazmayı bırakınca, Ctrl+S ile ve geri dönünce kaydedilir). Ada, düzenlemekte olduğunuz nota geri döner.
- **Kaynaklar:** BetterNotes (bu bilgisayarda, hesapsız), Joplin (Web Clipper servisi ve belirteci), Simplenote (hesap), Memos (sunucunuz ve bir belirteç).
- **Ayarlar:** Ayarlar → Notlar: bağlı uygulamalar, hızlı notların nereye gideceği, ne sıklıkla alınacakları, son notta devam etme.
- **Teşekkür:** BetterNotes'u [thebanri](https://github.com/thebanri/BetterNotes) geliştiriyor. Uygulama ve bu sayfanın konuştuğu komut satırı arayüzü için teşekkürler.
- **Gereksinim ve sınırlar:** belirteçler KDE Cüzdan'da tutulur. Kilitli bir BetterNotes notu ana parolayı sorar (BetterNotes 0.1.15 ya da daha yenisi; daha eskisiyle ada notu uygulamada açmayı önerir); parola komutun standart girdisine gider ve hiçbir yerde saklanmaz. Zengin metinli notlar düz metin olarak gösterilir ve salt okunurdur.

### Yapay Zeka

*Hızlı sorular için bir kutu.* Siz açana kadar kapalıdır.

<!-- GIF: ai-question.gif | Yapay Zeka sayfasında bir soru yazılıyor; üç nokta yanıtın yolda olduğunu gösteriyor; yanıt biçimlendirilmiş metin olarak beliriyor. Hazır yanıtlar veren bir demo sunucusu yanıtlıyor. | Yapay Zeka: bir soru ve yanıtı (demo sağlayıcı) -->

- **Ne görürsünüz:** bir alan, yazıldıkça görünen yanıt (Markdown, *Kopyala* düğmeli kutularda kod) ve hapta, yanıt yoldayken üç nokta, siz başka yerdeyken "Cevap hazır".
- **Nasıl kullanılır:** Ayarlar → Düzen: *Yapay Zeka*'yı açın. Sayfada neyin yanıt vereceğini bağlayın, sonra yazın; Enter gönderir, Shift+Enter yeni satırdır. *Yeni sohbet* baştan başlar; Escape klavyeyi geri verir.
- **Kim yanıt verebilir:** bu bilgisayardaki Claude Code ya da Antigravity; bu bilgisayardaki bir model sunucusu (Ollama, LM Studio, llama.cpp, Jan, KoboldCpp ya da OpenAI uyumlu herhangi bir adres); kendi anahtarınızla bir servis (Anthropic, OpenAI, OpenRouter, Groq, Google Gemini ya da OpenAI uyumlu bir başkası).
- **Ayarlar:** Ayarlar → Yapay Zeka: kaynaklar ve varsayılanı, en uzun yanıt ve soru, sohbeti bir dosyada saklama, adada "Cevap hazır".
- **Gereksinim ve sınırlar:** bu bir soru kutusudur, **ajan değildir**: hiçbir şeye araç ya da dosya verilmez; panonuzdan, ekranınızdan, notlarınızdan ya da takviminizden hiçbir şey eklenmez. Anahtarlar KDE Cüzdan'da tutulur. Bir servise sorulan soru o servise gönderilir ve o servisin ücretine tabi olabilir. Siz saklamayı seçmedikçe sohbet, kabuk durduğunda unutulur.

### Bulut

*rclone üzerinden bulutlarınızın klasörleri, adlarıyla.* Siz açana kadar kapalıdır.

<!-- GIF: cloud-browse.gif | Bulut sayfası bir uzağın klasörlerini listeliyor; bir klasör açılıyor; bir dosya masaüstüne sürükleniyor; bir başkası yüklemek için bırakılıyor. Uydurma bir uzakla gösterilmiştir. | Bulut: gezin, sürükleyip indir, bırakıp yükle (uydurma bir uzak) -->

- **Ne görürsünüz:** her rclone uzağı ve ne kadar dolu olduğu, boyut ve tarihiyle klasörleri ve dosyaları, bir istemcinin bildirdiği yerde senkron durumu (Syncthing, Dropbox) ve bulut dolmak üzereyken bir uyarı.
- **Nasıl kullanılır:** Ayarlar → Düzen: *Bulut*'u açın. Klasörlere tıklayarak girin; bir dosyayı masaüstüne ya da dosya yöneticisine sürükleyin; yüklemek için dosyaları sayfaya bırakın (önce sorar). *İndir*, *Klasörde göster*, *Yolu kopyala* ve *Yükle…* aynısını sürüklemeden yapar.
- **Ayarlar:** Ayarlar → Bulut: hangi uzakların hangi adla gösterileceği, eşikler (%90 ve %98), uyarılar ve duraklatması, yüklemeden önceki soru, önbellek ve *Önbelleği temizle*.
- **Gereksinim ve sınırlar:** en az bir uzağı olan `rclone` gerekir (`rclone config`); eksikse sayfa nasıl kurulacağını gösterir. Ada yalnızca `rclone` komutunu çalıştırır: listeleyebilir, ölçebilir, buluttan ve buluta kopyalayabilir; silemez, taşıyamaz, yeniden adlandıramaz, eşitleyemez. rclone'un kendi yapılandırması ve belirteçleri asla açılmaz.

### Pano

*Son kopyalananlar.*

<!-- GIF: clipboard-history.gif | Pano sayfası uydurma kopyalanmış metinleri ve bir resmi listeliyor; tıklama birini yeniden kopyalıyor; arama listeyi daraltıyor. | Pano -->

- **Ne görürsünüz:** Plasma'nın kendi panosunun (Klipper) geçmişi: metinler, kod, resimler, dosyalar.
- **Nasıl kullanılır:** tıklama bir girdiyi yeniden kopyalar; imlecin altında: yıldızla, QR kodu, düzenle, Klipper'ın eylemleri, kaldır. Bir arama alanı ve yalnızca yıldızlılar süzgeci.
- **Sınırlar:** ne kadarının tutulacağı Klipper'ın kendi ayarıdır; ada bunun hiçbirini saklamaz.

## İndirmeler ve dosya aktarımları

<!-- GIF: downloads-tracking.gif | Yerel bir test sunucusundan curl ile başlatılan indirme, megabaytı ve dolan bir halkayla hapta görünüyor; sonra boyutu ve süresiyle "İşlem bitti". | İndirme takibi (yerel bir test sunucusundan indirme) -->
<p align="center"><img src="docs/media/downloads-tracking.gif" alt="Yerel bir test sunucusundan curl ile başlatılan indirme, megabaytı ve dolan bir halkayla hapta görünüyor; sonra boyutu ve süresiyle &quot;İşlem bitti&quot;." width="800"><br><sub>İndirme takibi (yerel bir test sunucusundan indirme)</sub></p>

Dosya taşıyan her şey için tek tür etkinlik: adı, "412 MB / 1,8 GB", yüzde, hız, kalan süre ve sonunda dosyayı ya da klasörünü açan bir düğme.

| Kaynak | Ne gösterilir |
|---|---|
| Dolphin, Ark, uzak klasörlere yüklemeler (KDE'nin iş sistemi) | Her şey, tam olarak |
| KDE Connect, USB bellekler ve harici diskler | Aynısı, iş sistemi üzerinden |
| Tarayıcı indirmeleri | İndirme klasöründen okunan boyut, hız ve kalan süre |
| `git clone`, `wget`, `curl`, `pip download` | Süreçlerinden bulunur; bayt ve hız yazdıklarından |
| `apt`, PackageKit (Discover) | Aşama ve bilindiği yerde ilerleme |

**Ayarlar → İndirme Takibi:** ana anahtar, her kaynak, arka plan işleri, gösterilmek için bir şeyin ne kadar sürmesi ve ne kadar büyük olması gerektiği, izlenen klasörler ve komutlar. Komutlar süreç listesine üç saniyede bir bakılarak bulunur; hiçbir şey kurulmaz ya da sarmalanmaz. Gerçek programlarla neyin denenip neyin denenmediği [başvuru belgesinde](docs/REFERENCE.md#file-transfers-what-can-and-cannot-be-tracked) (İngilizce) yazılıdır.

## Öneriler

<!-- GIF: suggestions-card.gif | Bir ekran kaydı başlıyor ve ada, Evet, Şimdi değil ve bir daha önerme yanıtlarıyla bildirimlerin gizlenip gizlenmeyeceğini soruyor; ayar sayfası neyin öğrenildiğini gösteriyor. | Bir öneri ve öğrendiği -->

Birkaç belirli anda ada tek kısa bir soru sorabilir ("Ekran kaydedilirken bildirimler gizlensin mi?") ve üç yanıt sunar: evet, şimdi değil, asla. Yanıtlardan, her kural ve her durum için, sormayı mı, kendiliğinden yapmayı mı (söyleyerek ve geri alma seçeneğiyle), yoksa sessiz kalmayı mı seçeceğini öğrenir. Yalnızca kurallar ve sayım, bu bilgisayarda: ağ yok, model yok.

Kurallar: bir takvim etkinliğinden önce, ekran kaydı sırasında ve Pomodoro odak turunda Rahatsız Etmeyin; görüntülü toplantıdan önce, mikrofon kullanıldığında ve kulaklık çıkınca medyayı duraklatma; pil azaldığında güç tasarrufu.

**Ayarlar → Öneriler:** açık/kapalı (**varsayılan olarak kapalı**: siz açana kadar ada hiçbir şey önermez ve hiçbir şey öğrenmez), iki öneri arasındaki en az süre, her kural, anahtarı ve öğrendikleriyle, ve "unut".

## Kedi

<!-- GIF: cat-sleep.gif | Hapın yanındaki kedi kıvrılıp uyuyor; bir bildirim geliyor ve başını kaldırıyor. | Kedi: uykuda ve uyanık -->
<p align="center"><img src="docs/media/cat-sleep.gif" alt="Hapın yanındaki kedi kıvrılıp uyuyor; bir bildirim geliyor ve başını kaldırıyor." width="800"><br><sub>Kedi: uykuda ve uyanık</sub></p>
<!-- GIF: cat-petting.gif | İmleç kediyi sağdan sola okşuyor ve kalpler yükseliyor. | Kedi: okşama -->
<!-- GIF: cat-annoyed.gif | Uyuyan kediye tıklanıyor; sinirleniyor ve küsüyor. | Kedi: uyandırılınca -->

Hapın yanında küçük bir kedi oturur. Hiçbir şey olmayınca uykuya dalar (20 sn sonra), müzik çalarken kulaklık takar, Yapay Zeka yanıt verirken düşünür ve olaylarda başını kaldırır. Okşarsanız (imleci üzerinde sağa sola gezdirin) hoşuna gider; uyurken tıklarsanız gitmez. Hiçbir şeyi değiştirmez, hiçbir şey saklamaz ve ağdan hiçbir şey istemez.

**Ayarlar → Kedi:** gösterilip gösterilmeyeceği, taraf, boyut, tüy (gri, turuncu, siyah, beyaz, smokin ya da kendi renginiz), neye tepki verdiği, okşanıp tıklanabilirliği, asla sinirlenmeme, ne kadar küstüğü, ne zaman uyuduğu, noktanın yanında gizli mi uykuda mı olacağı ve **hareketi azaltma** (o zaman kıpırdamadan durur: kafa sallama ve kıpırtılar yok). Masaüstünün kendi animasyonları kapalıyken de hareketsizdir.

## Görünüm, temalar ve mağaza

<!-- GIF: appearance-looks.gif | Müzik çalarken aynı hap art arda dört hazır temada, sonra yeniden sistemin renklerinde. | Aynı ada, birkaç görünümde -->
<!-- GIF: appearance-themes.gif | Ayarlarda hazır bir tema seçiliyor, bir gradyan ayarlanıyor ve ada anında değişiyor; görünüm dosya olarak dışa aktarılıp yeniden ekleniyor. | Görünüm: temalar, gradyan, dışa aktarma ve ekleme -->

**Ayarlar → Görünüm** iki kip sunar.

- **Sistemi takip et** (varsayılan): arka plan, metin ve vurgu Plasma'dan gelir ve onunla birlikte anında değişir.
- **Özel:** hazır temalar (Oxygen Metallic, Breeze Dark, Breeze Light, Pure Glass, High Contrast ve dört gradyan: Aurora, Sunset, Ocean, Midnight Blue) ve ince ayar: opaklık, bulanıklık, üstten uzaklık, yatay konum, boyut (%80–120), köşe yuvarlaklığı, tek renk ya da gradyan, denetimlerin ve metnin renkleri, kenarlık, gölge. Pencere açıkken her değişiklik adada anında görünür. Bir görünüm bir adla kaydedilebilir.

**Tema dosyaları.** *Temayı Dışa Aktar…* görünümü tek bir `*.islandtheme.json` dosyası olarak yazar. *Yeni Ekle…* bir dosyadan ya da mağazadan geri alır. Bir tema **yalnızca veridir**: bilinen alanlardan oluşan en fazla 64 kB JSON; kod yok, QML yok, resim yok. Başka her şey reddedilir; sağlama toplamı katalogdakiyle uyuşmayan bir indirme de reddedilir. Eklediğiniz temalar `~/.local/share/dynamicisland/themes/` altında tutulur.

**Mağaza** bu deponun `catalog/` klasörünü listeler. Yalnızca sekmesini açtığınızda ve *İndir*'e bastığınızda istek yapar. Adresi tek bir sabittir (`contents/ui/ThemeFile.js` içinde `CATALOG_URL`): bu deponun `main` dalındaki `catalog/` klasörü, `raw.githubusercontent.com`'un sunduğu biçimiyle. Kataloğa kendi temanızı eklemek için: [CONTRIBUTING.md](CONTRIBUTING.md) (İngilizce).

## Düzen ve dil

<!-- GIF: layout-reorder.gif | Ayarlar → Düzen içinde bir sayfa başka bir yere sürükleniyor ve biri kapatılıyor; adanın sekmeleri buna uyuyor. | Düzen: sayfaları sıralama ve gizleme -->
<!-- GIF: language-switch.gif | Ayarlar → Dil English'ten Türkçe'ye çevriliyor; adanın metinleri anında değişiyor. | Dil -->

- **Ayarlar → Düzen → Sekmeler:** bir sayfayı tutamacından sürükleyip sekmesini taşıyın; anahtarı onu gösterir ya da gizler. *Varsayılan sıraya döndür* hepsini eski yerine koyar. **Modüller:** bir sayfanın içindeki açılıp kapatılabilen parçalar.
- **Ayarlar → Dil:** Otomatik, Türkçe ya da English; yalnızca ada ve ayarları için, Plasma'yı yeniden başlatmadan.

## Geliştiriciler için: kendi etkinliğini gönder

Her program D-Bus üzerinden adada bir etkinlik gösterebilir (oturum veri yolunda servis, yol ve arayüz `org.phobby.DynamicIsland`).

<!-- GIF: island-push.gif | Hapta "Backup" adlı bir etkinlik, dolan bir ilerleme halkasıyla beliriyor, sonra yeşil bir "bitti". | island-push ile gönderilen bir etkinlik -->
<p align="center"><img src="docs/media/island-push.gif" alt="Hapta &quot;Backup&quot; adlı bir etkinlik, dolan bir ilerleme halkasıyla beliriyor, sonra yeşil bir &quot;bitti&quot;." width="800"><br><sub>island-push ile gönderilen bir etkinlik</sub></p>

```bash
island-push --id build --title "Build" --progress 40 --icon run-build
island-push --id build --progress 80 --subtitle "linking…"
island-push --id build --done --status success
island-push --flash --title "Backup done" --icon document-save --color green
```

```bash
source /path/to/plasma-island/tools/notify-done.sh    # ~/.bashrc ya da ~/.zshrc içine
notify-done make -j16          # çalışırken adada, sonra "Bitti" ya da "Başarısız"; çıkış kodu korunur
```

| Yöntem | |
|---|---|
| `Push(s id, a{sv} props)`, `Update(…)` | Bir etkinlik oluşturur ya da değiştirir |
| `Finish(s id, s status)` | Bitirir: `success`, `error`, `cancel` ya da `""` |
| `Flash(a{sv} props)` | Anlık bir olay |
| `List() → as` | Etkin kimlikler |
| sinyal `ActivityClicked(s id)` | Kullanıcı tıkladı |

`props`: `title`, `subtitle`, `icon`, `progress` (0–100, yoksa −1), `color` (`red`, `green`, `blue`, `orange`, `purple`, `gray` ya da `#rrggbb`), `trailing`, `priority`, `category`, `timeout` (saniye), `duration` (ms, yalnızca Flash). Bir Go örneği ve `busctl` kullanımı [başvuru belgesindedir](docs/REFERENCE.md#d-bus-api) (İngilizce). Yerel modül gerekir; Ayarlar → Etkinlikler API'yi kapatır.

## Performans

<!-- PERF:BEGIN -->
| Durum | plasmashell | + KWin | + algılayıcı servisi | Uyanma/sn | Bellek (RSS / PSS) |
|---|---|---|---|---|---|
| Adasız aynı masaüstü | %0,00 | %0,00 | – | 0 | 212 / 68 MB |
| Her şeyi kapalı ada | %0,01 | %0,00 | %0,07 | 0 | 263 / 110 MB |
| Boşta, noktaya küçülmüş | %0,12 | %0,00 | %0,19 | 4 | 283 / 122 MB |
| Boşta, saatli hap, kedisiz | %0,12 | %0,00 | %0,20 | 4 | 282 / 120 MB |
| Boşta, varsayılan ayarlar (kedi uyuyor) | %0,40 | %0,11 | %0,19 | 66 | 284 / 123 MB |
| Kedi uyanık | %0,52 | %0,17 | %0,18 | 107 | 283 / 123 MB |

CPU, **tek** çekirdeğin yüzdesi olarak (makinede on iki iş parçacığı var); her biri iki dakikalık üç koşunun ortancası ("Adasız aynı masaüstü" için iki koşu), 60 Hz ekranlı izole bir oturumda. "+ KWin" ve "+ algılayıcı servisi", kabuğun yanında bileşikleyicinin ve Plasma'nın algılayıcı servisinin kullandığıdır ("–": servis çalışmıyordu). Tek bir masaüstü bilgisayarda ölçüldü (Ryzen 5 7500F, RTX 4060, Wayland üzerinde Plasma 6.6.6): sizin sisteminizde farklı olacaktır; yenileme hızı daha yüksek bir ekranda hareket eden her şey daha pahalıdır. **Adanın kodu bu ölçümlerden sonra değişti ve ölçümler yeni kodla tekrarlanmadı.** Yöntem, tüm senaryolar ve kendi ölçümünüzü nasıl alacağınız: [docs/PERFORMANCE.md](docs/PERFORMANCE.md) (İngilizce).

**Henüz ölçülmedi** (bunlar için rakam verilmiyor):

- Müzik çalarken; ortam ışığı ve kedi açıkken ve kapalıyken
- Özel görünümler: düz, bulanık cam, gradyan
- Bildirim yükü (80 saniyede 200 bildirim)
- D-Bus API'siyle gönderilen, her saniye değişen bir etkinlik
- İzlenen bir indirme
- Arka plan işleri: her biri dakikada bir sorulan hava durumu, iki takvim ve notlar
- Saniyedeki kare sayısı ve kare süreleri
- İki saatlik uzun koşu: bellek, iş parçacığı ya da dosya tanımlayıcı sayısı büyüyor mu
- Watt cinsinden enerji
- İmleç gerektiren her şey: üzerine gelme, açık bir sayfa, liste kaydırma, kediyi okşama
<!-- PERF:END -->

## Gizlilik ve ağ

**Telemetri yoktur**: ada kimseye hiçbir şey bildirmez ve hesabı yoktur. Ayarlar geldiği gibi bırakıldığında **hiçbir ağ isteği yapmaz** (doğrulandı: varsayılan ayarlarla sıfırdan bir başlangıç `strace` altında 170 sn izlendi, bilgisayarın dışına hiçbir bağlantı yok). Her parça, siz onu kullanınca şunları yapar:

| Parça | Ağla konuşur mu | Program başlatır mı | Diske ne yazar |
|---|---|---|---|
| Adanın kendisi, Sistem, bildirimler, medya | asla | `pw-dump` (bir tane; mikrofon/kamera/kayıt göstergeleri için); Plasma'nın algılayıcı servisi | ayarlarını, Plasma'nın kendi ayar dosyasına |
| Ortam ışığı (varsayılan kapalı) | asla | müzik çalarken `pw-record` | hiçbir şey |
| Hava Durumu | Open-Meteo ile, **yalnızca siz bir yer seçtikten sonra**: yazdığınız ad aramasına, yerin koordinatları tahminine gider (en sık 15 dakikada bir) | hiçbiri | yeri, ayarlara |
| Takvim | **yalnızca bir takvim bağladıktan sonra**: yapıştırdığınız `.ics` bağlantıları (5 dakikada bir) ya da bağlı bir hesap için iCloud / Google | Google girişi için bir kez tarayıcı | bağlantıları ve hesap adlarını ayarlara (özel bir bağlantı bir sırdır: orada düz metin olarak durur); parolalar ve belirteçler KDE Cüzdan'da |
| Notlar | **yalnızca bağlı bir uygulama için**: bu bilgisayardaki Joplin, Simplenote'un sunucuları, Memos sunucunuz; BetterNotes asla | `betternotes` komutu | belirteçler KDE Cüzdan'da (notların kendisi uygulamalarında kalır) |
| Yapay Zeka (varsayılan kapalı) | **yalnızca bir soru gönderdiğinizde**, seçtiğiniz kaynağa | o kaynaklar için `claude` ya da `agy` | anahtarlar KDE Cüzdan'da; sohbet yalnızca siz isterseniz (`~/.local/share/dynamicisland/ai-chat.json`, yalnızca sizin okuyabildiğiniz) |
| Bulut (varsayılan kapalı) | kurduğunuz uzaklar için `rclone` üzerinden: bir klasör açtığınızda listeleme, üç saatte bir her bulutun doluluğu | `rclone`; kullanıyorsanız `dropbox status` | aldığınız dosyalar `~/.cache/dynamicisland/cloud` içinde (boyut sınırıyla) |
| Tema mağazası | `raw.githubusercontent.com` (bu deponun `catalog/` klasörü), **yalnızca sekmesini açtığınızda** ya da İndir'e bastığınızda | hiçbiri | eklediğiniz temalar `~/.local/share/dynamicisland/themes/` içinde |
| Güncellemeler | asla (PackageKit'in bu bilgisayardaki listesini okur) | hiçbiri | hiçbir şey |
| İndirme takibi | asla | hiçbiri (süreç listesini ve indirme klasörünü okur) | hiçbir şey |
| Öneriler | asla | hiçbiri | öğrendiklerini `~/.local/share/dynamicisland/suggestions.json` içine |
| Alışkanlıklar, Pomodoro, Uygulamalar, Araçlar | asla | başlattığınız uygulamalar | verilerini ayarlara |
| Pano | asla | hiçbiri | hiçbir şey (geçmiş Klipper'ındır) |
| D-Bus API'si | asla | hiçbiri | hiçbir şey |

Bilinmesi gereken üç şey daha:

- **Kapalı bir sayfa iş yapmaz.** Yapay Zeka ve Bulut kapalıyken yüklenmez bile. Tüm sayfalar ve izleyiciler kapalıyken ada tek çekirdeğin %0,01'ini kullandı (adasız masaüstü: %0,00) ve işlemciyi saniyede birden az uyandırdı; yine de yaklaşık 50 MB bellek tutar (bkz. [Performans](#performans)).
- **Başkalarının yazdığı düz metin olarak gösterilir.** Bir bildirimin başlığı, bir parçanın, bir dosyanın ya da bir ağın adı asla biçimlendirme olarak okunmaz; bu yüzden adaya bir yerden resim çektiremez.
- **Programlar kabuk olmadan başlatılır**, her argüman ayrı ayrı; kilitli bir notun parolası programın standart girdisine gider, asla komut satırına değil.

## Sorun giderme

| | |
|---|---|
| Ada görünmüyor | Kurulumdan sonra plasmashell'i yeniden başlatın (`systemctl --user restart plasma-plasmashell`), sonra widget'ı ekleyin. Günlükler: `journalctl --user -f \| grep -i -E "dynamicisland\|qml"` |
| Bulanıklık yok, adanın yanındaki tıklamalar geçmiyor, sayfalar yerel modülün eksik olduğunu söylüyor | Yerel modül kurulu değil ya da plasmashell onu görmüyor: `./install.sh` çalıştırın (`--no-native` olmadan) ve plasmashell'i yeniden başlatın. Bir Plasma ya da Qt güncellemesinden sonra yeniden çalıştırın |
| Ada tıklamaları tam olarak nerede alıyor? | plasmashell'i ortamında `DYNAMICISLAND_DEBUG_REGION=1` ile başlatın: bölgenin çevresine kırmızı bir çerçeve çizilir (`systemctl --user set-environment DYNAMICISLAND_DEBUG_REGION=1`, plasmashell'i yeniden başlatın; sonra `unset-environment`) |
| Adaya yazı yazmak | Ada klavyeyi asla kendiliğinden almaz. Bir alana tıklanınca alır (Notlar, Yapay Zeka, bir yanıt) ve Escape ile geri verir; klavye ondayken ada açık kalır |
| Ada açılınca iki ada ya da iki kedi görünüyor | Araç aynı ekrana iki kez eklenmiş. Artık yalnızca ilki görünür; diğerini kaldırın (ipucu metni gizli olduğunu söyler) |
| BetterNotes kurulu ama "bulunamadı" | Ada `betternotes` komutunu (`PATH` üzerinde, `~/.local/bin` içinde) ve menü girdisini (Flatpak'inkini de) arar. Yalnızca indirildiği yerden çalıştırılan bir AppImage'ın ikisi de yoktur: `./BetterNotes-….AppImage install`. Sayfa yerel yardımcının eksik olduğunu söylüyorsa `./install.sh` çalıştırıp plasmashell'i yeniden başlatın |
| BetterNotes: kaydedemiyor, açamıyor, kilitli not | Kaydetmek için BetterNotes 0.1.13, bir notu uygulamada açmak için 0.1.14, kilitli notlar için 0.1.15 gerekir. Güncelledikten sonra çalışan eski BetterNotes'u kapatıp yeniden başlatın. `betternotes --diagnostics` kendi raporunu yazdırır |
| Bulut: "rclone bulunamadı" | rclone'u kurun ve kendi uçbiriminizde bir uzak ekleyin (`rclone config`); sayfa kopyalanacak komutları gösterir, hiçbirini çalıştırmaz |
| Hava Durumu hiçbir şey göstermiyor | Bilerek boş başlar: sayfada *Konum Seç* |
| Kaydırma liste yerine sayfayı çeviriyor (ya da tersi) | plasmashell'in ortamında `QT_LOGGING_RULES="island.wheel.debug=true"` her tekerlek adımını kimin aldığını günlüğe yazar |
| Ses iki kez görünüyor | Plasma'nın kendi penceresi ve adanınki: [Kurulum](#kurulum-güncelleme-kaldırma) bölümünün sonuna bakın |
| Adayı açmak için klavye kısayolu | Adanın kendine ait bir kısayolu yoktur. Plasma'nın widget başına kısayolu denenmedi |
| Günlük her başlangıçta `qt.qml.usedbeforedeclared … IcsWorker.js` satırları listeliyor | Zararsızdır: takvim kütüphanesinin (ical.js) kodundan gelirler |
| Kedinin tüm pozlarına bakmak | plasmashell'in ortamında `DYNAMICISLAND_CAT_GALLERY=1` hepsini gösteren bir pencere açar |

## Bilinen sınırlar

- **Yalnızca tek bir kurulum test edildi:** NVIDIA kartlı, tek monitörlü, Wayland üzerinde Plasma 6.6.6. X11, başka sürümler, birden fazla monitör ve kedinin taraf değiştirmesini gerektirecek kadar dar bir ekran denenmedi. X11'de tıklama bölgesi çizileni de kırpar; gölge ve ışık kesilebilir.
- **Ada**, widget'ın eklendiği masaüstünün ya da panelin ekranında durur.
- **Bildirimler iki kez görünür**: Plasma'nın penceresi ve adanınki. Ada tam ekran pencerelerin üzerinde kalabilir.
- **Adaya sürükleme:** yalnızca görünen ada bir sürüklemeyi alır; ada ile başka bir program arasında dosya sürükleme Qt'nin sunduğu biçimde yazıldı ama iki program arasında denenemedi.
- **İndirme takibi:** bir Flatpak tarayıcı, `git clone`, `wget`, `curl`, `pip download`, `apt download` ve bir PackageKit indirmesiyle denendi. `sudo apt update/install`, bir Chromium tarayıcı, Snap olarak Firefox ve tarayıcı içinde duraklatma denenmedi.
- **Takvim:** bağlantılar aralıklarla yoklanır; var olan bir etkinlik adadan düzenlenemez; bir etkinlik 20 sn'ye kadar geç pinlenebilir. Bir takvim bağlantısı en çok 10 MB gönderebilir ve en çok 30 saniye sürebilir; daha büyük ya da daha yavaş olan okunmaz (ada bunu söyler ve son sağlam kopyayı göstermeyi sürdürür).
- **Yapay Zeka:** Claude Code'un bir soru kutusu olarak kalması, komutun kendi seçeneklerine uymasına dayanır; ada her yanıttan önce komutun kendisi hakkında söylediklerini denetler ve aksi halde durdurur. Ollama dışındaki model sunucuları burada kurulu değildi; gerçek bir anahtarla sohbet bir vekil sunucuya karşı, gerçek servislere karşı ise yalnızca reddedilen bir anahtar denendi.
- **Bulut:** rclone üzerinden Google Drive, OneDrive ya da Nextcloud için senkron durumu yoktur; Syncthing ve Dropbox durumları vekillere karşı denendi.
- **Güncellemeler** PackageKit'in paketlerini sayar (apt, dnf); Flatpak güncellemeleri sayılmaz.
- **KDE Connect**'te "arama bitti" sinyali yoktur: arama etkinliği, bildirimi kapanınca biter.
- **Bluetooth kulaklıklar** sol, sağ ve kutu için ayrı değil, tek bir pil değeri verir.
- **D-Bus API'si** aynı anda tek bir adaya aittir (ilk kaydolan); bunun yanında ikinci bir "dynamic island" widget'ı üst üste biner.

Her parça için neyin denendiğini de içeren uzun liste [başvuru belgesindedir](docs/REFERENCE.md#known-limitations) (İngilizce).

## Katkı ve güvenlik

- **Kod, testler, mağaza için bir tema:** [CONTRIBUTING.md](CONTRIBUTING.md) (İngilizce). `tools/run-tests`, çalışan bir ada gerektirmeyen tüm denetimleri koşturur.
- **Bir güvenlik sorunu:** [SECURITY.md](SECURITY.md). Lütfen bunun için herkese açık bir kayıt açmayın.
- **Nasıl yapıldığı:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Her özellik ayrıntısıyla: [docs/REFERENCE.md](docs/REFERENCE.md). Neler değişti: [CHANGELOG.md](CHANGELOG.md). (Bu belgeler İngilizcedir.)

<!-- TODO(owner): yol haritası. Buraya yalnızca sahibinin karar verdikleri yazılır. -->

## Lisans ve teşekkürler

Ada, **GNU Genel Kamu Lisansı sürüm 2 ya da (tercihinize göre) daha sonraki bir sürümü** (`GPL-2.0-or-later`) altında özgür yazılımdır; lisansın metni [LICENSE](LICENSE) dosyasındadır.

Başkalarının emeği üzerinde durur; her lisansla birlikte tam liste [docs/CREDITS.md](docs/CREDITS.md) içindedir:

- Bir widget'ı olduğu [KDE Plasma](https://kde.org/plasma-desktop/) ve Qt.
- [Lucide](https://lucide.dev) (ISC; bazı simgeleri Feather'dan gelir, MIT): hava durumu resimleri ve Yapay Zeka sekmesinin ışıltısı.
- [ical.js](https://github.com/kewisch/ical.js) (MPL-2.0): takvim dosyalarını okuma.
- [Open-Meteo](https://open-meteo.com): hava durumu verisi, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) lisansıyla.
- [Simple Icons](https://simpleicons.org) (CC0): Apple ve Google takvim seçeneklerini ve Joplin ile Simplenote kaynaklarını etiketleyen işaretler. Bunlar sahiplerinin ticari markalarıdır.
- [BetterNotes](https://github.com/thebanri/BetterNotes) (MIT): simgesi ve Notlar sayfasının konuştuğu komut satırı arayüzü için teşekkürler.
- Yukarıdaki kliplerdeki müzik ve kapaklar bu proje için `tools/demo/make-media` ile üretilmiştir ve serbestçe kullanılabilir (CC0).
