# nos

`ghcr.io/ublue-os/base-nvidia:latest` (Fedora 44, NVIDIA sürücüleri dahil) üzerine KDE Plasma ekleyen kişisel bir bootc imajı. Hedef: gereksiz paket ve servis içermeyen, sade bir Plasma masaüstü.

## Dosyalar

- `Dockerfile`: İmajın tamamı. Tek bir `dnf5 install` katmanı ve `bootc container lint` var.
- `.github/workflows/build.yml`: Sadece elle tetikleniyor (`workflow_dispatch`). Podman ile build alıp `ghcr.io/<repo>:latest` ve `:<sha>` etiketleriyle push ediyor.
- `already-exists.txt`: Temel imajda kurulu gelen RPM'lerin listesi.
- `enabled-units.txt`: Temel imajda açık gelen systemd birimleri ve varsayılan hedef.
- `dir.txt`: Temel imajın kök dizin yapısı (`ls -la /`). Sadece referans için.

## Kurallar

- **Paket eklemeden önce** `already-exists.txt`'de ara. Temel imajda olan bir paketi listeye ekleme.
- **`systemctl enable` eklemeden önce** `enabled-units.txt`'de ara. Bluetooth, NetworkManager, firewalld, cups, sshd ve benzerleri zaten açık geliyor. Varsayılan hedef de zaten `graphical.target`.
- **Bir paketin başka paketlerle zaten gelip gelmediğini** temel imajın içinde kontrol et: `dnf5 install --assumeno <liste>` komutunu o paketle ve o paket olmadan çalıştırıp çıktıları karşılaştır. dnf5 önerilen paketleri (Recommends) varsayılan olarak kurduğu için bunlar da gelir.
- Plasma'da bir özellik "yok" gibi görünüyorsa, genelde eksik olan servis değil, KDE'deki ayar sayfası ya da widget'tır. Örneğin Wi-Fi zaten çalışıyordu, eksik olan `plasma-nm` arayüzüydü.
- Temel imaj değişmiş olabilir. Bu iki dosyayı ara sıra yeniden üret:
  ```
  docker run --rm ghcr.io/ublue-os/base-nvidia:latest rpm -qa | sort > already-exists.txt
  docker run --rm ghcr.io/ublue-os/base-nvidia:latest bash -c 'systemctl list-unit-files --state=enabled --no-legend | awk "{print \$1}" | sort; echo "default.target -> $(systemctl get-default)"' > enabled-units.txt
  ```
  `already-exists.txt`'nin mevcut biçimi `ad-epoch:sürüm-sürümnotu.mimari` şeklinde. Yeniden üretirken bu biçimi korumak için `rpm -qa --qf '%{NAME}-%{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\n'` kullan.
- **Build:** ublue imajları yaklaşık 128 katmanlı. Docker'ın overlay2 sınırı 125 olduğu için `docker build` başarısız olur; podman kullan. Yerelde `docker run` ile paket kontrolü yapmak ise sorunsuz çalışıyor.
- Dockerfile yorumları Türkçe, commit mesajları İngilizce ve conventional commit biçiminde (`chore:`, `fix:`, `dev:`).

## Paketler ve neden eklendiler

| Paket | Neden |
|---|---|
| `fish`, `fastfetch` | Kişisel tercih |
| `plasma-desktop`, `konsole`, `dolphin` | Temel masaüstü |
| `sddm`, `sddm-wayland-plasma` | Giriş ekranı. `sddm-wayland-plasma`, giriş ekranının KWin üzerinde Wayland ile çalışmasını seçiyor; liste dışında bırakılırsa dnf Weston'lu alternatifi seçebilir. Başka paketler ikisini de zaten çekiyor, ama bu seçim açıkça belirtilsin diye listede. |
| `bluedevil` | Bluetooth arayüzü. bluez servisi temel imajda var. |
| `plasma-nm` | Wi-Fi ve ağ arayüzü. NetworkManager temel imajda var. |
| `kwalletmanager5` | Sistem Ayarları'ndaki KDE Cüzdanı sayfası (cüzdanı kapatmak için). Adında 5 olsa da Plasma 6 sürümü. `kwalletmanager` adlı paket eski KDE4 sürümü, onu kurma. |
| `kscreen` | Ekran ayarları (çözünürlük, Hz, ölçekleme, çoklu monitör) |
| `sddm-kcm` | Giriş ekranı ayar sayfası |
| `kde-gtk-config`, `breeze-gtk` | GTK uygulamalarının Breeze temasıyla görünmesi |
| `kdegraphics-thumbnailers` | Dolphin'de PDF ve resim önizlemeleri |
| `ark`, `spectacle` | Arşiv yönetimi, ekran görüntüsü |
| `flatpak-kcm` | Flatpak izinlerini Sistem Ayarları'ndan yönetme |
| `kwrite`, `gwenview` | Metin editörü, resim görüntüleyici |
| `kde-connect` | Telefon entegrasyonu. Fedora'daki paket adı `kdeconnect` değil, `kde-connect`. |
| `plasma-systemmonitor`, `kinfocenter`, `plasma-disks` | Görev yöneticisi, sistem bilgisi, disk sağlık uyarıları |

`systemctl enable sddm.service`: sddm kurulunca zaten kendiliğinden açılıyor. Yine de satır bilinçli olarak tutuluyor, çünkü bu satır olmadan sistem giriş ekranı olmadan açılabilir.

## Servis ve güvenlik duvarı ayarları

- `sshd` kapatıldı (`systemctl disable sshd.service`), çünkü SSH ile bağlanılmayacak. `sshd.socket` zaten kapalı geliyor.
- firewalld'ın varsayılan bölgesi `public`. Temel imajda bu bölgede `dhcpv6-client mdns ssh` servisleri açık geliyor. `ssh` kaldırıldı, `kdeconnect` (1714–1764 TCP/UDP) eklendi. `kde-connect` paketi servis tanımını getiriyor ama portları kendisi açmıyor.
- `firewall-offline-cmd` ile ilgili üç not:
  - `--remove-service` eski bir seçenek ve başka seçeneklerle birlikte kullanılamıyor. Yerine `--remove-service-from-zone` kullan.
  - Ekleme ve çıkarma aynı komutta yapılamıyor; ayrı komutlar gerekiyor.
  - Komut, bölge dosyasının yedeğini `.old` uzantısıyla bırakıyor; bunu sil.

## Bilinçli olarak eklenmeyenler

- `ffmpegthumbs`: Başka bir paket onu zaten öneri (Recommends) olarak kuruyor.
- `power-profiles-daemon`: powerdevil, güç profili servisi olarak `tuned-ppd`'yi zaten getiriyor. İkisi çakışır.
- `kdeplasma-addons`: Sadece Color Picker widget'ı istenmişti. Fedora'da bu widget ayrı bir paket olarak yok; bütün koleksiyonu kurmaya gerek görülmedi.
- Tarayıcı: Helium, Distrobox içinde (AUR veya `.deb` ile) kullanılacak. Flathub'da ve Fedora depolarında yok.
- Flathub: Elle eklemeye gerek yok. `flatpak-add-fedora-repos` servisi (ublue tarafından değiştirilmiş) ilk açılışta Flathub'ı açık olarak, Fedora'nın Flatpak depolarını ise kapalı olarak ekliyor.
- Distrobox, podman, Flatpak, ffmpeg, GStreamer codec'leri, emoji fontları ve CUPS temel imajda zaten var.

## Açık konular

- Güvenlik duvarı kuralı bir container içinde doğrulandı, ama KDE Connect'in telefonla gerçekten eşleşip eşleşmediği kurulu bir sistemde test edilmedi.
- Uygulama mağazası (Discover ya da Bazaar) eklenmedi; karar verilmedi.
