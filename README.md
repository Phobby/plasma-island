# Dynamic Island — Plasma 6 plasmoid

Ekranın üst-ortasında duran, iOS Dynamic Island mantığında çalışan hap
biçimli bir plasmoid. Görsel dili Oxygen'den esinlenen metalik cam
(grafit gradyan, gümüş kenar, üst parlama, iç ve dış gölge) ve arkası KWin
ile blur'lanmış.

Test edilen ortam: Kubuntu, Plasma 6.6.6, Qt 6.10.2, Wayland.

## Durumlar

| Durum | Ne zaman | Görünüm |
|---|---|---|
| Boşta | Hiçbir şey yokken | Küçük hap (180×36): saat veya durum noktası; medya duraklatılmışsa ⏸ işareti |
| Canlı etkinlik (compact) | En öncelikli kalıcı etkinlik | Medya: albüm kapağı + parça adı + equalizer. Diğerleri: solda renkli ikon, sağda süre/değer veya ilerleme halkası |
| Bölünmüş ada (split) | Aynı anda iki kalıcı etkinlik | Ana hapta birinci, sağında "damla" gibi ayrılan dairede ikinci etkinlik (minimal görünüm) |
| Bildirim | Yeni bildirim gelince | Uygulama ikonu (KDE Connect ise telefon rozeti), uygulama adı, başlık, metnin ilk satırı. Sol tık varsayılan eylemi çalıştırır, orta tık kapatır |
| Anlık olay | Şarj, Bluetooth, ses, Caps Lock… | Geniş hap: ikon, başlık, sağda halka / pil / kaydırıcı / düğme. 2–4 sn sonra ada kaldığı yere döner |
| Genişletilmiş | Fare üzerine gelince veya tıklanınca | Sayfalar (aşağıda) |
| Gizlilik noktaları | Mikrofon / kamera kullanımda | Adanın sağında turuncu (mikrofon) / yeşil (kamera) nokta, her durumda görünür |

Genişletilmiş sayfalar: **Etkinlikler** (tüm kalıcı etkinlikler, işlemler ve
gizlilik ayrıntıları), **Medya**, **Sistem** (yalnızca bilgi: CPU, CPU
sıcaklığı, GPU, RAM, pil, ağ ↓/↑ ve disk kartları; Sabit veya Dinamik görünüm),
**Bildirimler** (son 3, geliş saati, hızlı yanıt, onaylı "tümünü sil"),
**Denetim** (Rahatsız Etmeyin, Gece Işığı, güç profili, Bluetooth, Wi-Fi,
güncellemeler; altında ses ve ekran parlaklığı kaydırıcıları), **Araçlar** (zamanlayıcı, kronometre,
Pomodoro, alarm), **Cihazlar** (Bluetooth cihazları ve telefonlar, pilleriyle).

### Etkinlik yöneticisi ve öncelik

Her özellik bağımsız bir *sağlayıcıdır* (`contents/ui/providers/`). Sağlayıcılar
`ActivityManager`'a **kalıcı etkinlik** (`Activity`, sürdüğü sürece adada) veya
**anlık olay** (`flash()`, birkaç saniye) gönderir. Varsayılan öncelik
(Ayarlar → Etkinlikler'den değiştirilebilir):

`gizlilik > arama > ekran kaydı > anlık olaylar > zamanlayıcı/Pomodoro/takvim > dosya işleri/özel etkinlikler > medya > boşta`

- Anlık olaylar, kendilerinden düşük öncelikli kalıcı etkinliği geçici olarak
  örter. Üstte bir etkinlik varken (ör. ekran kaydı) sırada bekler; 30 sn'den
  eski bekleyen olaylar atılır. Gelen arama bu kuralı aşar.
- Birden fazla anlık olay sıraya alınır; aynı türden olaylar (ör. ses) tek
  olayda birleştirilir.
- Ada genişletilmişken olaylar bekler. Ses/parlaklık gibi anlık geri bildirimler
  ise beklemez, atlanır.
- Bölünmüş adada en öncelikli iki kalıcı etkinlik gösterilir. Çalan medya ilk
  ikiye giremiyorsa (ör. iki zamanlayıcı varken) sağdaki daireyi albüm kapağı
  alır; "Çalan medyayı görünür tut" ayarıyla kapatılabilir.

**Neden sayfalı yerleşim?** Dört modülü alt alta dizmek adayı ~360 px
yüksekliğinde bir panele çevirir ve ekranın üstünü kapatır. Sayfalı yapıda ada
her zaman aynı kompakt boyutta (~430×207) kalır; iOS'taki gibi tek bir "kart"
hissi verir. Sayfalar sekmeyle, fare tekerleğiyle veya touchpad kaydırmasıyla değişir. Ada açıldığında medya çalıyorsa Medya sayfası, aksi
halde Sistem sayfası gösterilir. Sistem sayfası yalnızca durum gösterir;
ayarlanabilir her şey (ses, parlaklık, düğmeler) Denetim sayfasındadır.

## Kurulum

```bash
./install.sh               # plasmoid + native modüller + island-push
./install.sh --no-native   # yalnızca plasmoid (QML özellikleri)
./install.sh --remove      # hepsini kaldırır
```

Native modüller için derleme paketleri:
`cmake extra-cmake-modules qt6-base-dev qt6-declarative-dev libkf6windowsystem-dev`.
Ayrıca `pw-dump` (pipewire-bin) çalışma zamanında gerekir.

Native modüllere bağlı özellikler: şekilli blur, ekran kaydı, mikrofon/kamera
göstergeleri, kilit açılışı, KDE Connect aramaları, güncelleme sayısı ve D-Bus
API'si. Native modül yoksa bu özellikler kendini gizler, geri kalan her şey
çalışır. Aynı şekilde, eksik bir KDE modülü (ör. KDE Connect, bluez-qt,
plasma-nm) yalnızca kendi özelliğini devre dışı bırakır.

Ardından plasmashell'i yeniden yükleyin:

```bash
systemctl --user restart plasma-plasmashell   # önerilen
# veya
plasmashell --replace & disown
```

## Yerleştirme

Adanın kendisi ayrı bir üst pencere olduğundan, plasmoid'i **nereye eklediğiniz
önemli değildir**. Ada her zaman eklendiği ekranın üst-ortasında görünür.

- **Masaüstüne** ekleyin (Sağ tık → Pencere öğeleri ekle… → "Dynamic Island").
  Masaüstünde yalnızca küçük bir tutamak ikonu görünür. Ayarlara sağ tıkla
  ulaşılır.
- **veya bir panele** ekleyin. Panelde de sadece küçük bir ikon kaplar.
  İkona tıklamak adayı açar/kapatır.
- Üstte bir paneliniz varsa **"Üst panellerin altına yerleştir"** açıkken ada
  panelin hemen altında durur. Kapatırsanız ada panelin *üzerinde* (çentik
  gibi) durur; bu durumda "Üstten uzaklık" değerini panele göre ayarlayın.

## Ayarlar

| Ayar | Açıklama |
|---|---|
| Stil | Renk şemasını izle / Hep koyu (grafit, varsayılan) / Hep açık (alüminyum) |
| Saydamlık | Yüzey opaklığı (%30–100). Blur yokken en az %90 uygulanır |
| Blur | Arkadaki içeriği blur'la (native yardımcı gerekir) |
| Saat | Boştayken ve genişletilmiş başlıkta saat |
| Üstten uzaklık / panellerin altı | Konum |
| Bildirimler, gösterme süresi | Bildirim anı davranışı |
| Hover gecikmesi / ayrılınca kapanma | Varsayılan 120 ms / 400 ms |
| Tercih edilen oynatıcı | Örn. `spotify`. Çalıyorsa (veya başka hiçbir şey çalmıyorsa) bu oynatıcı gösterilir; boşsa Plasma otomatik seçer. Kimlik/desktop dosyası adında büyük-küçük harf duyarsız eşleşir |
| Modüller | Medya (canlı aktiviteyi de açar), Sistem, Ses, Son bildirimler |
| Sistem görünümü | Sabit (5 kart, 2 satır) / Dinamik (varsayılan: o an etkin olan kartlar büyür, boşluk kalmaz) |

**Etkinlikler** sekmesi: öncelik sıralaması (yukarı/aşağı), bölünmüş ada
açık/kapalı, çalan medyayı görünür tut, indirme klasörünü izle, anlık olay süresi, her sistem olayı ve canlı etkinlik türü için
ayrı açma/kapama, genişletilmiş sayfalar.
**Uyarılar** sekmesi: düşük/kritik pil eşiği, Bluetooth cihazı/telefon pil
eşiği, CPU/GPU sıcaklık eşiği, takvim hatırlatma süresi.
**Araçlar** sekmesi: zamanlayıcı/alarm bitiş sesi (dosya seçilebilir), Pomodoro
süreleri ve tur sayısı.

Zamanlayıcı, kronometre, Pomodoro ve alarmın bitiş zamanları ayarlarda saklanır;
plasmashell yeniden başlasa da kaldıkları yerden devam ederler.

## Test ve hata ayıklama

```bash
# Tek başına önizleme (plasma-sdk paketi):
sudo apt install plasma-sdk
plasmoidviewer -a org.phobby.dynamicisland

# plasma-sdk olmadan, plasma-workspace ile gelen araç:
plasmawindowed org.phobby.dynamicisland

# Native yardımcıyı kurmadan build dizininden denemek:
QML_IMPORT_PATH=$PWD/native/build/qml plasmawindowed org.phobby.dynamicisland

# plasmashell içindeki loglar:
journalctl --user -f | grep -iE "dynamicisland|qml"
```

Not: `plasmawindowed`/`plasmoidviewer` ayrı bir süreçte çalışır. Bildirim ve
iş (job) servisi plasmashell'e ait olduğundan bu modda bildirimler ve dosya
işleri **görünmez** (`Failed to register Notification service on DBus` mesajı
normaldir). Bunları gerçek ortamda (widget plasmashell'de eklenmişken) deneyin.

### Modül modül test

| Modül | Nasıl tetiklenir |
|---|---|
| Bildirim | `notify-send "Test" "Merhaba"` · birden fazla: `for i in 1 2 3; do notify-send "Test $i"; done` |
| Rahatsız Etmeyin | Denetim sayfasındaki ay düğmesi veya sistem tepsisindeki bildirimler → Rahatsız Etmeyin; açıkken `notify-send` gösterilmez, kapatınca kaçırılan sayı yazar |
| Medya | Spotify/Elisa/tarayıcıda bir şey çalın; `playerctl play-pause` |
| Ses / çıkış cihazı | `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+` · `wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle` · çıkış cihazını değiştirin |
| Parlaklık | Denetim sayfasındaki kaydırıcı; parlaklık tuşları (dizüstü) veya DDC destekli monitör |
| Şarj / pil | Dizüstünde şarj kablosunu takıp çıkarın (masaüstünde bu modül gizlenir) |
| Güç profili | `powerprofilesctl set performance` → `powerprofilesctl set balanced` |
| Bluetooth | `bluetoothctl connect <MAC>` / `bluetoothctl disconnect <MAC>` |
| Klavye | Caps Lock / Num Lock tuşları; düzen değişimi: `qdbus6 org.kde.keyboard /Layouts org.kde.KeyboardLayouts.switchToNextLayout` |
| Wi-Fi / VPN | `nmcli radio wifi off/on` · `nmcli connection up <vpn>` / `down` · hotspot: `nmcli device wifi hotspot` |
| Ekran kaydı | Spectacle ile ekran kaydı, OBS, tarayıcıda ekran paylaşımı |
| Mikrofon | `pw-record /tmp/test.wav` (Ctrl+C ile durdurun) |
| Kamera | Kamera uygulaması (ör. Kamoso) veya tarayıcıda kamera testi |
| Kilit açılışı | `loginctl lock-session`, ardından kilidi açın |
| Dosya işi | Dolphin ile büyük bir dosya kopyalayın veya `ark --batch` ile arşiv açın (`kioclient` iş izleyicisini kullanmaz, görünmez) |
| İndirme | Tarayıcıdan büyük bir dosya indirin (Flatpak/Snap tarayıcılarda yalnızca boyut ve hız görünür) |
| Zamanlayıcı vb. | Genişletilmiş → Araçlar sayfası (1 dk'lık zamanlayıcı en hızlı test) |
| Takvim | PIM takvim eklentisi (KOrganizer/Akonadi) kuruluysa 15 dk içinde başlayacak bir etkinlik ekleyin |
| KDE Connect | `kdeconnect-cli --list-devices` · `kdeconnect-cli -d <id> --ping` · telefondan dosya gönderin / telefonu arayın |
| Güncellemeler | Denetim sayfası; `pkcon get-updates` ile karşılaştırın |
| Sıcaklık | Ayarlar → Uyarılar'da eşiği düşürün (ör. 50 °C) |
| Özel etkinlik | `island-push --id demo --title "Demo" --progress 30` → `island-push --id demo --done --status success` |

## Mimari

```
org.phobby.dynamicisland/
├── metadata.json
├── contents/config/{main.xml, config.qml}
└── contents/ui/
    ├── main.qml               PlasmoidItem, üstte duran Dialog, arka uç Loader'ları, sağlayıcılar
    ├── ActivityManager.qml    kalıcı etkinlikler + öncelik + anlık olay kuyruğu
    ├── Activity.qml           bir canlı etkinlik (minimal / compact / expanded)
    ├── Island.qml             durum makinesi, morph, bölünmüş ada, gizlilik noktaları
    ├── ExpandedContent.qml    sekmeler + sayfalar
    ├── PlasmaBackend.qml      ┐ private Plasma/KDE API'leri YALNIZCA
    ├── backend/*.qml          ┘ bu iki yerde (her biri Loader ile isteğe bağlı)
    ├── providers/*.qml        her özellik: Media, Notification, Power, Bluetooth, Osd,
    │                          Keyboard, Network, Dnd, Recording, Privacy, Jobs, Timer,
    │                          Stopwatch, Pomodoro, Alarm, Calendar, KdeConnect,
    │                          Thermal, Updates, Dbus, Unlock; transferler için
    │                          KdeConnectTransfer, RemovableTransfer, BrowserDownload
    ├── TransferActivity.qml, TransferHub.qml, TransfersCard.qml   ortak transfer etkinliği
    ├── Theme.qml, IslandShape.qml, ActivityCompact/Minimal/Card.qml, EventBanner.qml,
    │   BatteryGlyph.qml, MiniRing.qml, …        ortak görsel dil
    ├── *Module.qml, *Page.qml                    genişletilmiş sayfalar
    ├── NativeBridge.qml, BlurBridge.qml          native modülleri içe aktarır
    └── config*.qml                                ayar sayfaları
native/
├── windowblur.*               org.phobby.dynamicisland.effects (şekilli KWin blur)
└── core/                      org.phobby.dynamicisland.core:
                               PipeWireWatcher, DBusSignalWatcher, Launcher,
                               UpdatesChecker, DownloadWatcher,
                               IslandService (D-Bus API)
tools/island-push, tools/notify-done.sh
```

**Yeni bir özellik eklemek:** `providers/` altına bir dosya yazın. İçinde bir
`Activity { … Component.onCompleted: manager.register(this) }` tanımlayın
ve/veya `manager.flash({ icon, color, title, subtitle, trailing })` çağırın.
Ardından sağlayıcıyı `main.qml`'deki `providers` bloğuna ekleyin. Varsayılan
compact/minimal/expanded görünümleri istemiyorsanız `compact`, `minimal`,
`expanded` özelliklerine kendi `Component`'inizi verin.

**Gizlilik ve ekran kaydı tespiti:** native `PipeWireWatcher`, `pw-dump
--monitor` çıktısını olay tabanlı dinler (polling yok). Mikrofon: gerçek bir
`Audio/Source`'a bağlı çalışan kayıt akışı (ses ölçerleri ve masaüstü sesini
yakalayan uygulamaları saymaz). Kamera: v4l2/libcamera cihaz düğümünü tüketen
akış. Ekran: cihaz olmayan video kaynağını (KWin/portal ekran yayını) tüketen
akış. plasmashell'in kendi pencere önizlemeleri sayılmaz.

**Pencere stratejisi (b: tek çerçevesiz Dialog):** Masaüstü widget'ları
pencerelerin altında kalır. Panel + ayrı popup (a) yaklaşımında ise küçük hap
ile büyük kart iki ayrı pencere olur ve morph animasyonu pencere değişiminde
kopar. Bu yüzden ada tek bir `PlasmaCore.Dialog` içinde çizilir:
`type: Notification` + `WindowDoesNotAcceptFocus` (hep üstte, odak çalmaz),
`NoBackground` (yüzeyi kendimiz çizeriz). Konum `x/y` ile atanır. Wayland'de
bunu plasmashell'in plasma-shell protokolü yapar; Plasma'nın kendi bildirim
popup'ları da aynı yöntemi kullanır. Pencerenin yalnızca iki boyutu vardır
(küçük hap / büyük kart). Morph animasyonu pencerenin *içinde* oynar, pencere
her karede yeniden boyutlanmaz. Küçülme animasyonu bitince pencere küçülür.

**Blur:** KWin bir pencerenin yalnızca istediği bölgeyi blur'lar.
`PlasmaQuick::Dialog` bu bölgeyi tema çerçevesinin SVG maskesinden hesaplar
ve QML'den değiştirilemez (`libPlasmaQuick` içinde doğrulandı). Hap biçimli
bölge için `native/` altındaki küçük modül
`KWindowEffects::enableBlurBehind(window, true, roundedRegion)` çağırır ve
bölgeyi animasyonla birlikte günceller. Modül kurulu değilse `BlurBridge.qml`
yüklenemez ve yüzey yarı opak metale geçer.

**Performans:** Boşta çalışan tek şey dakikada bir uyanan saat zamanlayıcısıdır.
Sensörler (`Sensor.enabled`) sadece Sistem sayfası görünürken, oynatıcı pozisyon
sorgusu sadece Medya sayfası görünür ve çalarken aktiftir. Equalizer
animasyonları görünmezken durur. Görünmeyen sayfalar yüklenmez; bildirim listesi
modele sadece görünürken bağlanır.

**Private API'ler:** `org.kde.plasma.private.mpris`,
`org.kde.plasma.private.volume`, `org.kde.plasma.private.battery`,
`org.kde.notificationmanager`, `org.kde.ksysguard.sensors` yalnızca
`PlasmaBackend.qml` içinde; `org.kde.plasma.private.batterymonitor`,
`org.kde.bluezqt`, `org.kde.plasma.private.brightnesscontrolplugin`,
`org.kde.plasma.private.keyboardindicator`,
`org.kde.plasma.workspace.keyboardlayout`, `org.kde.plasma.networkmanagement`,
`org.kde.taskmanager`, `org.kde.plasma.workspace.calendar` ve
`org.kde.kdeconnect` yalnızca `backend/` altında kullanılır. Sağlayıcılar ve
görünümler sadece bu dosyaların normalize edilmiş özelliklerini görür. Bir
Plasma güncellemesi API'yi değiştirirse düzeltilecek yer burasıdır.

## D-Bus API

Herhangi bir program kendi canlı etkinliğini gönderebilir:

| | |
|---|---|
| Servis | `org.phobby.DynamicIsland` (oturum veriyolu) |
| Nesne | `/org/phobby/DynamicIsland` |
| Arayüz | `org.phobby.DynamicIsland` |
| `Push(s id, a{sv} props)` | Etkinlik oluştur/güncelle |
| `Update(s id, a{sv} props)` | `Push` ile aynı |
| `Finish(s id, s status)` | Bitir; `success` (yeşil), `error` (kırmızı), `cancel` veya `""` (sessiz) |
| `Flash(a{sv} props)` | Tek seferlik anlık olay |
| `List() → as` | D-Bus ile gönderilmiş etkin kimlikler |
| sinyal `ActivityClicked(s id)` | Kullanıcı etkinliğe veya bitiş olayına tıkladı |

`props`: `title` s, `subtitle` s, `icon` s, `progress` i (0–100, −1 = yok),
`color` s (`red|green|blue|orange|purple|gray` veya `#rrggbb`), `trailing` s,
`priority` i, `category` s (`timer|transfer|recording|call|media`; varsayılan
`transfer`), `timeout` i (sn, otomatik bitir), `duration` i (ms, yalnızca Flash).

### island-push

```bash
island-push --id build --title "Derleme" --progress 40 --icon run-build
island-push --id build --progress 80 --subtitle "bağlanıyor…"
island-push --id build --done --status success
island-push --flash --title "Yedek alındı" --icon document-save --color green
island-push --list
```

### notify-done

```bash
source ~/dev/plasma-island/tools/notify-done.sh   # ~/.bashrc veya ~/.zshrc içine
notify-done make -j16        # sürerken adada, bitince yeşil "Done" / kırmızı "Failed"
```

Çıkış kodu korunur, bu yüzden `notify-done make && ./run` gibi zincirler bozulmaz.

### Başka bir programdan (Go örneği)

```go
package main

import (
	"time"

	"github.com/godbus/dbus/v5"
)

func main() {
	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		panic(err)
	}
	island := conn.Object("org.phobby.DynamicIsland", "/org/phobby/DynamicIsland")
	const iface = "org.phobby.DynamicIsland."

	for p := 0; p <= 100; p += 20 {
		island.Call(iface+"Push", 0, "sync", map[string]dbus.Variant{
			"title":    dbus.MakeVariant("Senkronizasyon"),
			"subtitle": dbus.MakeVariant("Nextcloud"),
			"icon":     dbus.MakeVariant("folder-sync"),
			"color":    dbus.MakeVariant("blue"),
			"progress": dbus.MakeVariant(int32(p)),
		})
		time.Sleep(time.Second)
	}
	island.Call(iface+"Finish", 0, "sync", "success")

	// Tıklamaları dinlemek için:
	conn.AddMatchSignal(dbus.WithMatchInterface("org.phobby.DynamicIsland"), dbus.WithMatchMember("ActivityClicked"))
}
```

`busctl` ile: `busctl --user call org.phobby.DynamicIsland /org/phobby/DynamicIsland
org.phobby.DynamicIsland Push 'sa{sv}' demo 2 title s "Merhaba" progress i 50`

## Plasma OSD'si ile birlikte kullanım

Ses ve parlaklık değişince ada ince bir kaydırıcı gösterir; Plasma'nın kendi
OSD'si de görünmeye devam eder. İkisinden birini seçin:

- **Adadaki göstergeyi kapatmak:** Ayarlar → Etkinlikler → "Volume, brightness
  and audio output".
- **Plasma'nın ses OSD'sini kapatmak:** Sistem Ayarları → Ses → sağ üstteki
  menü (⋮) → yapılandırma sayfasındaki "Show OSD popups for changes to:"
  (Türkçe arayüzde "Şu değişiklikler için OSD açılır pencereleri göster")
  altındaki ses/mikrofon/sessiz seçeneklerinin işaretini kaldırın. Plasma 6'da
  parlaklık OSD'sini kapatacak bir ayar yok; sistemi bozacak bir değişiklik
  yapılmadı.

## Bilinen kısıtlamalar

- **Çift bildirim:** Plasma'nın kendi bildirim popup'ları kapatılamaz. Ada
  bildirimleri *ek olarak* gösterir. Sistem Ayarları → Bildirimler → Konum ile
  sistem popup'larını başka bir köşeye alabilirsiniz.
- **Blur** native yardımcıyı, KWin'de "Bulanıklaştır" efektinin açık olmasını
  ve plasmashell'in `QML_IMPORT_PATH`'i görmesini gerektirir.
  `install.sh` bunu `~/.config/environment.d/` ve
  `systemctl --user set-environment` ile ayarlar; plasmashell'i yeniden
  başlatmak gerekir. Plasma güncellemelerinden sonra (Qt/KF6 ABI değişirse)
  `./install.sh` ile yeniden derleyin.
- **Wayland konumlandırma** plasmashell'e ayrıcalıklı olarak verilen
  plasma-shell protokolüne dayanır. Başka bir süreçte bu mümkün olmayabilir;
  bu makinede `plasmawindowed` ile de çalıştığı doğrulandı.
- **Tam ekran uygulamalar:** Notification tipindeki pencereler tam ekran
  videoların/oyunların üstünde kalabilir.
- **Sensörler:** CPU sıcaklığı `cpu/all/maximumTemperature`, GPU `gpu/all/usage`
  ve ilk bulunan `gpu/gpuN/temperature` (N=0–2) ile okunur. Sürücü değer
  vermiyorsa ilgili kart gizlenir. Ağ kartındaki yay, yakın zamandaki en
  yüksek hıza göre anlık doluluğu gösterir.
- **Çoklu monitör:** Ada, widget'ın eklendiği containment'ın ekranında durur.
- Adanın küçük penceresi hapın biraz dışını (gölge payı) kapsar. Bu birkaç
  piksellik saydam alan tıklamaları yakalar.
- Aynı anda başka bir "dynamic island" widget'ı (ör. `com.arvin.dynamicisland`)
  etkinse ikisi üst üste biner.
- **Bluetooth kulaklık pilleri:** BlueZ yalnızca tek bir pil değeri verir.
  AirPods gibi kulaklıklarda sol/sağ/kutu pilleri ayrı okunamaz; tek değer
  gösterilir.
- **Hotspot:** NetworkManager hotspot'a bağlı istemci sayısını bildirmez. Ada
  yalnızca "Hotspot açık" kalıcı etkinliğini gösterir.
- **Ekran kaydını durdurma:** başka bir uygulamanın ekran yakalamasını durdurmak
  için genel bir API yok. Genişletilmiş görünümde "uygulamaya geç" düğmesi var.
- **KDE Connect aramaları:** KDE Connect "arama bitti" sinyali yaymaz. Görüşme
  etkinliği, KDE Connect'in arama bildirimini kapatmasıyla (veya güvenlik
  zaman aşımıyla) biter. SMS/mesaj hızlı yanıtı yalnızca yanıt destekleyen
  bildirimlerde görünür.
- **Takvim** yalnızca Plasma'nın PIM takvim eklentisi (`pimevents`,
  KOrganizer/Akonadi) kuruluysa çalışır; yoksa modül gizlenir.
- **Güncellemeler** PackageKit önbelleğinden okunur (apt/dnf paketleri).
  Flatpak güncellemeleri sayılmaz.
- **D-Bus API** aynı anda yalnızca bir ada örneğine bağlanır (ilk kayıt olan).
- **Dosya işleri ve bildirimler** yalnızca widget plasmashell içinde
  çalışırken görünür.

## Dosya transferleri: ne izlenebilir, ne izlenemez

Tüm transferler ortak `TransferActivity`/`TransferHub` üzerinden gösterilir:
kaynak adı, yüzde, kalan süre (mm:ss) ve bitişte "Tamamlandı"/"Gönderildi"
ya da kırmızı "Başarısız". Kalan süre yalnızca kaynak bildiriyorsa ya da
hızdan hesaplanabiliyorsa gösterilir; tahmini/sahte süre gösterilmez.

| Kaynak | Sağlayıcı | Durum |
|---|---|---|
| Dolphin kopyala/taşı/sil, Ark çıkarma, uzak konumlara (sftp/smb/MTP) kopyalama | `JobsProvider` | Tam destek (KDE iş sistemi) |
| KDE Connect dosya alma/gönderme | `KdeConnectTransferProvider` | Tam destek; "Pixel 7 → Computer: foto.jpg" |
| USB/harici disk (`/media`, `/run/media`) | `RemovableTransferProvider` | Tam destek; "USB DISK → Belgeler: rapor.pdf" |
| Tarayıcı indirmesi + Plasma Browser Integration eklentisi | `BrowserDownloadProvider` | Tam destek (yüzde, süre) |
| Tarayıcı indirmesi, eklenti yok / Flatpak-Snap tarayıcı (ör. Zen) | `BrowserDownloadProvider` + native `DownloadWatcher` | İndirme klasöründeki `*.part`/`*.crdownload` izlenir: indirilen boyut ve hız var, **yüzde ve kalan süre yok** (tarayıcı toplam boyutu diske yazmaz) |
| Tarayıcıdan yükleme (upload) | — | **İzlenemez**: tarayıcı yüklemeleri hiçbir sistem API'sine iş olarak düşmez |

Neden Zen indirmeleri görünmüyordu: Zen bir Flatpak uygulaması; sandbox içinden
sistemdeki Plasma Browser Integration host'una ulaşamadığı için indirmeleri KDE
iş sistemine hiç düşmüyordu. Klasör izleyici bu boşluğu kapatır.
Not: `kioclient` komut satırı aracı KDE iş izleyicisini kullanmaz; test için Dolphin veya `ark --batch` kullanın.
