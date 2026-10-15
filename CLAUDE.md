# nos

`ghcr.io/ublue-os/base-nvidia:latest` (Fedora 44, NVIDIA sürücüleri dahil) üzerine KDE Plasma ekleyen kişisel bir bootc imajı. Hedef: gereksiz paket ve servis içermeyen, sade bir Plasma masaüstü.

## Dosyalar

- `Dockerfile`: İmajın tamamı. Tek bir `dnf5 install` katmanı ve `bootc container lint` var.
- `.github/workflows/build.yml`: Sadece elle tetikleniyor (`workflow_dispatch`). Podman ile build alıp `ghcr.io/<repo>:latest` ve `:<sha>` etiketleriyle push ediyor.
- `dir.txt`: Temel imajın kök dizin yapısı (`ls -la /`). Sadece referans için.

## Kurallar

- **Temel imajdaki paketler:** Hepsini listeye yazma, ama doğrudan kullandığımız birini (bir servisini açtığımız ya da bir özelliği için ona dayandığımız) listeye yaz. Temel imajdan çıkarılırsa da kurulur.
- **İstediğimiz her paketi listeye açıkça yaz**, başka bir paketin bağımlılığı ya da önerisi (Recommends) olarak zaten gelse bile. Amaç, neyin bilinçli olarak kurulduğunu listeden görebilmek ve Fedora bağımlılıkları değiştirse de imajın bozulmaması. Bu yüzden "başka paketle zaten geliyor mu" diye kontrol etmeye gerek yok.
- **İhtiyaç duyduğumuz her servisi `systemctl enable` ile açıkça aç**, temel imajda ya da preset ile zaten açık gelse bile. Varsayılan hedef (`graphical.target`) için de aynısı geçerli.
- İstenmeyen bir öneri paketi gelirse `--exclude` ile açıkça hariç tut (bkz. Discover).
- Plasma'da bir özellik "yok" gibi görünüyorsa, genelde eksik olan servis değil, KDE'deki ayar sayfası ya da widget'tır. Örneğin Wi-Fi zaten çalışıyordu, eksik olan `plasma-nm` arayüzüydü.
- Temel imajda bir paketin ya da servisin olup olmadığını öğrenmek gerekirse imajın içinde sor: `docker run --rm ghcr.io/ublue-os/base-nvidia:latest rpm -q <paket>` ya da `... systemctl is-enabled <servis>`.
- **Build:** ublue imajları yaklaşık 128 katmanlı. Docker'ın overlay2 sınırı 125 olduğu için `docker build` başarısız olur; podman kullan. Yerelde `docker run` ile paket kontrolü yapmak ise sorunsuz çalışıyor.
- Dockerfile yorumları Türkçe, commit mesajları İngilizce ve conventional commit biçiminde (`chore:`, `fix:`, `dev:`).

## Paketler ve neden eklendiler

| Paket | Neden |
|---|---|
| `bluez`, `NetworkManager-wifi`, `firewalld`, `flatpak`, `distrobox`, `python3` | Temel imajda zaten var. Doğrudan kullandığımız için listede. |
| `fish`, `fastfetch` | Kişisel tercih |
| `plasma-desktop`, `konsole`, `dolphin` | Temel masaüstü |
| `sddm`, `sddm-wayland-plasma` | Giriş ekranı. `sddm-wayland-plasma`, giriş ekranının KWin üzerinde Wayland ile çalışmasını seçiyor; liste dışında bırakılırsa dnf Weston'lu alternatifi seçebilir. Başka paketler ikisini de zaten çekiyor, ama bu seçim açıkça belirtilsin diye listede. |
| `bluedevil` | Bluetooth arayüzü. bluez servisi temel imajda var. |
| `plasma-nm` | Wi-Fi ve ağ arayüzü. NetworkManager temel imajda var. |
| `kwalletmanager5` | Sistem Ayarları'ndaki KDE Cüzdanı sayfası (cüzdanı kapatmak için). Adında 5 olsa da Plasma 6 sürümü. `kwalletmanager` adlı paket eski KDE4 sürümü, onu kurma. |
| `kscreen` | Ekran ayarları (çözünürlük, Hz, ölçekleme, çoklu monitör) |
| `sddm-kcm` | Giriş ekranı ayar sayfası |
| `kde-gtk-config`, `breeze-gtk` | GTK uygulamalarının Breeze temasıyla görünmesi |
| `kdegraphics-thumbnailers`, `ffmpegthumbs` | Dolphin'de PDF, resim ve video önizlemeleri |
| `ark`, `spectacle` | Arşiv yönetimi, ekran görüntüsü |
| `flatpak-kcm` | Flatpak izinlerini Sistem Ayarları'ndan yönetme |
| `plasma-discover`, `plasma-discover-flatpak` | Flatpak uygulama mağazası. `plasma-discover-packagekit` ve `plasma-discover-offline-updates` `--exclude` ile hariç tutuluyor: sistem bootc ile güncellendiği için Discover'ın RPM güncellemeleri çalışmaz. |
| `tuned`, `tuned-ppd` | Pil menüsündeki güç profilleri. powerdevil bunu zaten öneriyor; açıkça listede. `power-profiles-daemon` ile çakışır, onu ekleme. |
| `kwrite`, `gwenview` | Metin editörü, resim görüntüleyici |
| `kde-connect` | Telefon entegrasyonu. Fedora'daki paket adı `kdeconnect` değil, `kde-connect`. |
| `plasma-systemmonitor`, `kinfocenter`, `plasma-disks` | Görev yöneticisi, sistem bilgisi, disk sağlık uyarıları |

## Servis ve güvenlik duvarı ayarları

- Açıkça açılan servisler: `sddm`, `NetworkManager`, `bluetooth`, `firewalld`, `tuned`, `tuned-ppd`. Varsayılan hedef: `graphical.target`. Bunların çoğu zaten açık geliyor; kurala göre yine de yazılıyor.
- `sshd` kapatıldı (`systemctl disable sshd.service`), çünkü SSH ile bağlanılmayacak. `sshd.socket` zaten kapalı geliyor.
- firewalld'ın varsayılan bölgesi `public`. Temel imajda bu bölgede `dhcpv6-client mdns ssh` servisleri açık geliyor. `ssh` kaldırıldı, `kdeconnect` (1714–1764 TCP/UDP) eklendi. `kde-connect` paketi servis tanımını getiriyor ama portları kendisi açmıyor.
- `firewall-offline-cmd` ile ilgili üç not:
  - `--remove-service` eski bir seçenek ve başka seçeneklerle birlikte kullanılamıyor. Yerine `--remove-service-from-zone` kullan.
  - Ekleme ve çıkarma aynı komutta yapılamıyor; ayrı komutlar gerekiyor.
  - Komut, bölge dosyasının yedeğini `.old` uzantısıyla bırakıyor; bunu sil.

## bootc lint uyarıları

`bootc container lint` iki uyarı veriyordu; ikisi de çözüldü:
- `nonempty-run-tmp`: Paket kurulumu sırasında `/run/sddm` ve `/run/tuned` oluşuyor. `/run` sadece çalışma zamanına ait olduğu için bunlar imajda kalmamalı; `rm -rf` ile siliniyor. Yeni bir paket `/run` altında dizin bırakırsa onu da bu satıra ekle.
- `var-tmpfiles`: `/var` altındaki her içerik için bir tmpfiles.d girdisi olmalı. tuned paketi `/var/lib/tuned`'ı oluşturuyor ama girdisini getirmiyor. Girdi `/usr/lib/tmpfiles.d/nos-tuned.conf` dosyasına yazılıyor.

## Bilinçli olarak eklenmeyenler

- `power-profiles-daemon`: `tuned-ppd` ile çakışır.
- `kdeplasma-addons`: Sadece Color Picker widget'ı istenmişti. Fedora'da bu widget ayrı bir paket olarak yok; bütün koleksiyonu kurmaya gerek görülmedi.
- Tarayıcı: Helium, Distrobox içinde (AUR veya `.deb` ile) kullanılacak. Flathub'da ve Fedora depolarında yok.
- Flathub: Elle eklemeye gerek yok. `flatpak-add-fedora-repos` servisi (ublue tarafından değiştirilmiş) ilk açılışta Flathub'ı açık olarak, Fedora'nın Flatpak depolarını ise kapalı olarak ekliyor.
- podman, ffmpeg, GStreamer codec'leri, emoji fontları ve CUPS temel imajda zaten var.

## Açık konular

- Güvenlik duvarı kuralı bir container içinde doğrulandı, ama KDE Connect'in telefonla gerçekten eşleşip eşleşmediği kurulu bir sistemde test edilmedi.
