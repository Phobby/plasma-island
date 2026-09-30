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
| Canlı aktivite | Bir MPRIS oynatıcı çalarken | Solda yuvarlak albüm kapağı, ortada parça adı, sağda hareketli equalizer |
| Bildirim | Yeni bildirim gelince | Uygulama ikonu, uygulama adı, başlık, metnin ilk satırı. Sol tık varsayılan eylemi çalıştırır, orta tık kapatır. Bildirimler sıraya alınır; fare üzerindeyken süre durur. |
| Genişletilmiş | Fare üzerine gelince veya tıklanınca | Sayfalar: **Medya**, **Sistem** (CPU, CPU sıcaklığı, GPU kullanımı + sıcaklığı, RAM, ağ ↓/↑ ve varsa pil halkaları; altında ses) ve **Bildirimler** (son 3) |

Öncelik sırası: genişletilmiş > bildirim > canlı > boşta.

**Neden sayfalı yerleşim?** Dört modülü alt alta dizmek adayı ~360 px
yüksekliğinde bir panele çevirir ve ekranın üstünü kapatır. Sayfalı yapıda ada
her zaman aynı kompakt boyutta (~430×207) kalır; iOS'taki gibi tek bir "kart"
hissi verir. Sayfalar sekmeyle, fare tekerleğiyle veya touchpad kaydırmasıyla değişir. Ada açıldığında medya çalıyorsa Medya sayfası, aksi
halde Sistem sayfası gösterilir. Ses kontrolü tek başına bir sayfayı
doldurmadığı için Sistem sayfasının altında yer alır.

## Kurulum

```bash
./install.sh               # plasmoid'i kurar (zaten kuruluysa -u ile günceller)
./install.sh --with-blur   # + gerçek blur için native yardımcıyı derleyip kurar
./install.sh --remove      # kaldırır
```

`--with-blur` için gereken derleme paketleri:
`cmake extra-cmake-modules qt6-base-dev qt6-declarative-dev libkf6windowsystem-dev`.

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

Not: `plasmawindowed`/`plasmoidviewer` ayrı bir süreçte çalışır. Bildirim
servisi plasmashell'e ait olduğundan bu modda bildirimler **görünmez**
(`Failed to register Notification service on DBus` mesajı normaldir).
Bildirimleri gerçek ortamda `notify-send "Başlık" "Metin"` ile deneyin.

## Mimari

```
org.phobby.dynamicisland/
├── metadata.json
├── contents/config/{main.xml, config.qml}
└── contents/ui/
    ├── main.qml               PlasmoidItem + üstte duran PlasmaCore.Dialog + blur Loader
    ├── PlasmaBackend.qml      ← TÜM private Plasma API'leri yalnızca burada
    ├── Theme.qml              renkler, ölçüler (gridUnit tabanlı), süreler
    ├── IslandShape.qml        metalik cam yüzey
    ├── Island.qml             durum makinesi, morph animasyonu, bildirim kuyruğu
    ├── ExpandedContent.qml    sekmeler + sayfalar
    ├── MediaModule.qml / SystemModule.qml / VolumeModule.qml / NotificationModule.qml
    ├── NotificationBanner.qml, Clock.qml, Equalizer.qml, AlbumArt.qml,
    │   RingGauge.qml, GlassSlider.qml, IconButton.qml
    ├── BlurBridge.qml         native modülü içe aktarır (yoksa sessizce düşer)
    └── configGeneral.qml
native/                        isteğe bağlı C++ QML modülü: org.phobby.dynamicisland.effects
```

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
`org.kde.notificationmanager`,
`org.kde.ksysguard.sensors` yalnızca `PlasmaBackend.qml` içinde kullanılır.
Diğer dosyalar sadece onun normalize edilmiş özelliklerini görür. Bir Plasma
güncellemesi API'yi değiştirirse düzeltilecek tek dosya burasıdır.

## Bilinen kısıtlamalar

- **Çift bildirim:** Plasma'nın kendi bildirim popup'ları kapatılamaz. Ada
  bildirimleri *ek olarak* gösterir. Sistem Ayarları → Bildirimler → Konum ile
  sistem popup'larını başka bir köşeye alabilirsiniz.
- **Blur** native yardımcıyı, KWin'de "Bulanıklaştır" efektinin açık olmasını
  ve plasmashell'in `QML_IMPORT_PATH`'i görmesini gerektirir.
  `install.sh --with-blur` bunu `~/.config/environment.d/` ve
  `systemctl --user set-environment` ile ayarlar; plasmashell'i yeniden
  başlatmak gerekir. Plasma güncellemelerinden sonra (Qt/KF6 ABI değişirse)
  `./install.sh --with-blur` ile yeniden derleyin.
- **Wayland konumlandırma** plasmashell'e ayrıcalıklı olarak verilen
  plasma-shell protokolüne dayanır. Başka bir süreçte bu mümkün olmayabilir;
  bu makinede `plasmawindowed` ile de çalıştığı doğrulandı.
- **Tam ekran uygulamalar:** Notification tipindeki pencereler tam ekran
  videoların/oyunların üstünde kalabilir.
- **Sensörler:** CPU sıcaklığı `cpu/all/maximumTemperature`, GPU `gpu/all/usage`
  ve ilk bulunan `gpu/gpuN/temperature` (N=0–2) ile okunur. Sürücü değer
  vermiyorsa ilgili halka gizlenir. Ağ halkasının yayı, yakın zamandaki en
  yüksek hıza göre anlık doluluğu gösterir.
- **Çoklu monitör:** Ada, widget'ın eklendiği containment'ın ekranında durur.
- Adanın küçük penceresi hapın biraz dışını (gölge payı) kapsar. Bu birkaç
  piksellik saydam alan tıklamaları yakalar.
- Aynı anda başka bir "dynamic island" widget'ı (ör. `com.arvin.dynamicisland`)
  etkinse ikisi üst üste biner.
