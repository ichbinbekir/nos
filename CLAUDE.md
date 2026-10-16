# nos

Arch Linux tabanlı, KDE Plasma'lı kişisel bir bootc imajı. Kullanıcıya yönelik açıklama, kurulum ve kullanım: [README.md](README.md).

## Çalışma şekli (önemli)

- **Proje sahibi yapıyı Claude'a bırakmıştır.** Justfile, workflow'lar, build aşamaları gibi teknik yapıyı bilmiyor ve bunlarla uğraşmak istemiyor. Ne istediğini söyler (ör. "şu uygulama olsun", "şunu kaldır"); Claude bunu aşağıdaki kurallar çerçevesinde uygun yere ekler, gerekirse yapıyı düzenler.
- Kararları Claude verir ve kısaca, teknik olmayan bir dille açıklar. Sadece gerçekten sahibine ait kararlar için soru sorar (ör. donanımı hakkında bilinmeyen bir bilgi, bir uygulamayı isteyip istemediği).
- İstek kurallarla çelişiyorsa (ör. ağır bir paket, donanıma uymayan bir şey) bunu söyleyip daha hafif bir alternatif önerir.
- README.md'yi güncel tut: Başka kullanıcıların bilmesi gerekenler (amaç, donanım, kurulum, kullanım) orada. CLAUDE.md'ye sadece projede çalışan AI'ın bilmesi gerekenler yazılır.
- Bütün imajı yerelde build edip test etme; doğrulama GitHub Actions'ta yapılıyor. Paket adı gibi küçük kontroller web API'leriyle yapılabilir.

## Temel kurallar

**En temel amaç: sahibinin önüne açınca çalışan, rahat kullanılan, hafif bir makine getirmek.** Aşağıdaki kurallar bu amaca hizmet eder; çeliştiklerinde "çalışır ve rahat" önce gelir.

1. **Hafif ama aşırı sıkı değil.** Masaüstü ve uygulamalar sadece kullanılanlardan oluşur; bir uygulama eklemeden önce Flatpak ya da Distrobox ile daha hafif bir yolu var mı düşünülür. Ama Linux'ta normalde bulunan, arada bir gerekebilecek genel araçlar (git, openssh, bluez-utils, man sayfaları, dosya sistemi araçları) kesilmez.
2. **Sahibinin donanımı: Intel işlemci, NVIDIA ekran kartı.** Açıkça başka bir donanıma özel olan paketler (adında `amd`, `radeon` vb. geçen; ör. `amd-ucode`) eklenmez. Ama eksik çıkmasın diye `linux-firmware` bütün olarak kurulur; firmware'i üreticilere bölmeye uğraşılmaz.
3. **Tek tarayıcı Helium** (AUR, imajın içinde). Başka tarayıcı eklenmez.
4. **Güvenlik duvarı ufw.** firewalld kullanılmıyor; sahibi için ufw daha anlaşılır.

Paketleri ve servisleri "zaten geliyor olsa bile açıkça yaz" kuralı kaldırıldı (2026-10-15). Bağımlılık olarak zaten gelen bir şeyi listeye yazmak gerekmiyor; listede şu an duranlar ise kalabilir.

## Yapı

Yapı iki kaynaktan birleştirildi:
- **bootcrew/mono** (`arch/`, `shared/`): Arch'ı bootc ile açılabilir yapan kısım. bootc kaynaktan derleniyor, pacman yolları `/usr/lib/sysimage`'a taşınıyor, initramfs dracut ile üretiliyor, bootc dizin düzeni kuruluyor.
- **ublue-os/image-template**: Repo düzeni (`build_files/`, `system_files/`, Justfile) ve CI.

Önceki Fedora (ublue `base-nvidia`) sürümü git geçmişinde: `d0ae1b9`.

### Dosyalar

- `Containerfile`: Build aşamaları.
- `build_files/build.sh`: Paket listesi, servisler ve ayarlar. Değişikliklerin çoğu burada yapılır.
- `build_files/aur.sh`: AUR paketlerinin listesi (`AUR_PACKAGES`) ve derlenmesi.
- `build_files/bootc/`: bootcrew betikleri ve Apache-2.0 `LICENSE` dosyası. `bootc-rootfs.sh` ve `build-bootc.sh` değiştirildi; değişiklikler dosyaların başında yazıyor. Ayrıca `Containerfile`: `nos-bootc` imajı (aşağıda).
- `system_files/`: İmaja olduğu gibi kopyalanan dosyalar (SDDM Wayland ayarı, sudoers, resolv.conf tmpfiles, ilk kurulum ve güncelleme servisleri, fastfetch ayarı ve logosu).
- `tools/logo-gen.py`: fastfetch logosunu (NOS tüpü) üretir; build'in parçası değil. `--install` seçili versiyonu `system_files/usr/share/nos/fastfetch-logo.txt`'ye yazar. Sahibinin seçimi "c" versiyonu (gövde `c`, etiket `;`, harfler `M`), açık mavi renkler.
- `Justfile`: `build`, `build-bootc`, `rechunk` (chunkah), `disk-image`, `convert` (vdi ya da qcow2).
- `.github/workflows/build.yml`: Push, PR, her gün 04:00 UTC ve elle. "Build bootc"tan bağımsız (sahibinin isteği: elle bootc build'i ana build'i tetiklemesin, gerekirse ana build'i kendisi elle başlatır). `nos-bootc:latest` yoksa build hata verir (ör. paket silinirse önce "Build bootc" çalıştırılmalı; ilk kurulumdaki "yoksa atla" kontrolü işi bitince kaldırıldı). Build → rechunk → push (`latest`, `YYYYMMDD`, kısa SHA) → cosign imzası (`SIGNING_SECRET` secret'ı tanımlıysa; anahtar şifreli olduğu için şifresi `COSIGN_PASSWORD` secret'ında).
- `.github/workflows/build-bootc.yml`: `nos-bootc` imajını build eder (`ghcr.io/<sahip>/nos-bootc:<sürüm>` ve `:latest`). Her gün 03:00 UTC yeni bootc sürümü var mı bakar (yoksa atlar); pazartesileri sürüm aynı olsa da yeniden derler (Arch kütüphaneleri için); bootc derleme dosyaları değişince ve elle tetiklenince her zaman derler.
- `.github/workflows/build-disk.yml`: Elle tetikleniyor. Yayınlanmış imajdan sanal makine için VirtualBox (vdi, varsayılan) ya da QEMU (qcow2) disk imajı üretiyor. Sahibi VirtualBox kullanıyor.
- `LICENSE`: Proje MIT. İstisnalar Apache-2.0: `build_files/bootc/` (kendi `LICENSE` dosyası korunmalı) ve Justfile'daki `rechunk` tarifi. Başka projelerden kod alınırsa kaynağı ve lisansı belirtilir, `LICENSE`'taki istisnalar listesine eklenir.
- `cosign.pub`: İmza doğrulama anahtarı. `cosign.key` `.gitignore`'da, asla commit'lenmemeli.

### Build aşamaları

**nos-bootc** (`build_files/bootc/Containerfile`, ayrı imaj): Arch imajında bootc'nin yayınlanmış bir sürümünü (`BOOTC_VERSION`, boşsa en sonuncusu) SELinux desteği olmadan derler; son aşama `FROM scratch` ve içinde sadece bootc'nin kurulum dosyaları var (Arch ya da derleme araçları yok). bootc 1.17'den beri varsayılan olarak libselinux istiyor; Arch'ın resmi depolarında yok. Bu yüzden `CARGO_OPTIONS='--no-default-features --features "install-to-disk pre-6.15"'` kullanılıyor. bootc'ye yeni bir varsayılan özellik eklenirse bu listeye eklenmesi gerekebilir (her crate'in `[features] default`'una bak). bootc derlemesi kendi man sayfalarını üretmek için bootc'yi ikinci kez derliyor (~5–6 dk); bilerek bırakıldı (bootc Makefile'ı man sayfalarını zorunlu tutuyor, atlamak kırılgan; zaten sadece haftalık).

**nos** (`Containerfile`):
1. `ctx`: `build_files` ve `system_files`. Sadece bind mount ile kullanılır, imaja girmez.
2. `bootc`: `BOOTC_IMAGE` (varsayılan `ghcr.io/ichbinbekir/nos-bootc:latest`; CI ve Justfile sahibin adını küçük harfle veriyor).
3. `aur-builder`: AUR paketlerini `build` kullanıcısıyla `makepkg` ile derler.
4. `system`: Arch imajı + `COPY --from=bootc / /` → pacman yolları `/usr/lib/sysimage`'a taşınır → `build.sh` → `initramfs.sh` → `bootc-rootfs.sh` → `bootc container lint`.

Önceden derlenmiş bootc, Arch kütüphaneleri büyük sürüm atlarsa (soname değişikliği) bozulabilir. Haftalık yeniden derleme bunu sınırlıyor; olursa `bootc container lint` bootc'yi çalıştırdığı için ana build düşer ve bozuk imaj yayınlanmaz. Çözüm: "Build bootc"u elle çalıştırmak, bitince ana build'i de elle çalıştırmak.

## Teknik notlar

- Paket adlarını Arch'ta doğrula: `https://archlinux.org/packages/search/json/?name=<paket>`. Fedora adları farklı olabiliyor (ör. `kde-connect` → `kdeconnect`, `kwrite` → `kate` paketinin içinde).
- **AUR paketi eklemek:** `aur.sh`'deki `AUR_PACKAGES` listesine ekle. PGP anahtarları `.SRCINFO`'daki `validpgpkeys`'ten otomatik alınıyor.
- **`/opt` imajın içinde gerçek bir dizin.** bootcrew onu `/var/opt`'a yönlendiriyordu; AUR paketleri (Helium) `/opt`'a kurulduğu için değiştirildi.
- **NoExtract:** Resmi Arch Docker imajı man sayfalarını, belgeleri ve çevirileri kurmuyor (`pacman.conf` sonundaki `NoExtract` satırları). `build.sh` bu satırların hepsini siler ve önceden kurulu paketleri yeniden kurar; sonuç normal bir Arch kurulumu gibi olur. Bunu kaldırma, yoksa Türkçe arayüz, klavye ve man sayfaları çalışmaz.
- **ufw:** Build sırasında ufw çalışmıyor; `ufw allow`/`ufw default` kuralları sadece `/etc/ufw` altındaki dosyalara yazıyor. `/etc/ufw/ufw.conf`'ta `ENABLED=yes` ve `ufw.service` açık olunca açılışta uygulanıyor. Gelen bağlantılar kapalı, sadece KDE Connect (1714–1764 TCP/UDP) açık.
- **SDDM Wayland:** `system_files/usr/lib/sddm/sddm.conf.d/10-wayland.conf` giriş ekranını KWin üzerinde Wayland ile çalıştırıyor. sddm paketi Xorg'a bağımlı olduğu için Xorg kuruluyor ama kullanılmıyor.
- **Ağ:** NetworkManager + systemd-resolved (`/etc/resolv.conf` tmpfiles ile yönlendiriliyor). bootcrew'daki `systemd-networkd` kullanılmıyor. `openssh` kurulu ama `sshd` açılmıyor (sadece istemci).
- **İlk açılış (`nos-firstboot`):** systemd-firstboot işe yaramıyor: `/etc/passwd` ve `/etc/shadow` var olduğu için root şifresini, yerel ayar dosyaları yüzünden dil/klavyeyi atlıyor; Arch'ta root `*` ile kilitli (`filesystem` paketi), bu yüzden ilk VirtualBox denemesinde girilecek hesap yoktu. systemd-firstboot maskelendi; yerine `nos-firstboot.service` + `/usr/libexec/nos-firstboot` (system_files) giriş ekranından önce tty1'de **gum** arayüzüyle (ok tuşları, arama, gizli şifre kutusu) saat dilimi, dil, klavye, bilgisayar adı, kullanıcı adı, görünen ad ve şifre soruyor.
  - Sahibinin kuralı: **yarım kurulum kesinlikle olmasın.** Önce bütün sorular, sonra özet + onay; onaydan önce sistemde hiçbir şey değişmiyor. Uygulama adımları tekrar çalıştırılabilir (`timedatectl`, `localectl set-locale/set-keymap`, `hostnamectl`, `useradd`/`usermod -G wheel -s /usr/bin/fish`, `chpasswd`); hata olursa "Tekrar dene / Baştan başla". `firstboot-started` işareti varken yarıda kalmış kurulum baştan sorulur; bitti işareti (`/var/lib/nos/firstboot-done`) ancak her adım başarılı olunca yazılır. Ctrl+C engelli, servis `Restart=on-failure`.
  - Kurulum hiç başlamamışken normal bir kullanıcı varsa (switch) hiçbir şey sormadan bitti işaretini yazıyor.
  - Kullanıcının kabuğu fish. Metin ekranı yazı tipi `eurlatgr` (`/etc/vconsole.conf`; varsayılan yazı tipinde ğ/ş/ı yok). Arayüz Türkçe. root kilitli kalıyor, `wheel` sudo kullanabiliyor.
  - İlk (bash) sürüm VirtualBox'ta çalıştı; gum sürümü henüz denenmedi.
- **Dosya sistemi:** btrfs (sahibinin tercihi). İmajın içinde değil, kurulumda `bootc install to-disk --filesystem btrfs` ile seçiliyor (README ve Justfile'daki `filesystem`). btrfs desteğinin initramfs'e girmesi için `btrfs-progs` paketinin `initramfs.sh`'den önce kurulu olması gerekiyor; listeden çıkarılmamalı. bootc btrfs'i alt birimler (subvolume) ve anlık görüntü (snapshot) ayarı olmadan, tek bir dosya sistemi olarak kuruyor; sistem için geri alma zaten bootc'de var.
- **Otomatik güncelleme (`nos-update.timer` + `.service`, system_files):** bootc'nin kendi `bootc-fetch-apply-updates.timer`'ı kullanılmıyor: Fedora onu paketinde açıyor, biz bootc'yi elle kurduğumuz için kapalı; şartı `/run/ostree-booted` composefs yapısında yok (bootc composefs açılışını `/proc/cmdline`'daki `composefs=` ile anlıyor); ve `--apply` ile kendiliğinden yeniden başlatıyor. `nos-update` açılıştan 10 dk sonra ve her 6 saatte bir `bootc upgrade` (yeniden başlatmadan, bir sonraki açılışta devreye girer) çalıştırıyor; `ConditionKernelCommandLine=composefs`, `network-online.target` (`NetworkManager-wait-online` açık), düşük öncelik. Hazırlanan güncellemeyi kapanışta `bootc-finalize-staged.service` uyguluyor; onu `bootc upgrade` kendisi başlatıyor (kaynakta `start_finalize_stated_svc`). Güncelleme hazırlanınca kullanıcıya bildirim yok (ileride eklenebilir). Gerçek sistemde denenmedi.
- **Sistem adı ve logo:** `build.sh` `/usr/lib/os-release`'i yazıyor: `NAME/PRETTY_NAME=nos`, `ID=nos`, `ID_LIKE=arch` (Arch'a göre davranan araçlar için; EndeavourOS/CachyOS gibi), `VERSION_ID` = build tarihi, `LOGO=archlinux-logo` (kendi simgemiz yok, KDE "Bu Sistem Hakkında"da Arch logosu görünür). `/etc/os-release` bağlantıya çevriliyor (Arch Docker imajı onu düz dosya yapıyor). initramfs'ten önce yazıldığı için açılış menüsünde de `nos` görünmesi bekleniyor (denenmedi). fastfetch: `/etc/xdg/fastfetch/config.jsonc` logo dosyasını ve renkleri (`$1`..`$5`, turuncu `38;5;208`) veriyor; modüller fastfetch'in varsayılanı. Terminal açılışında fastfetch otomatik çalışmıyor; sahibi bilerek istemedi.
- **bootc lint:** `build.sh` `/run` ve `/tmp` tmpfs'iyle çalışıyor; `/var` ise `bootc-rootfs.sh` tarafından boşaltılıyor.
- Betikler Containerfile'da `bash /ctx/...` ile çalıştırılıyor (Windows'ta yazılan dosyaların çalıştırma izni yok). `.gitattributes` her şeyi LF tutuyor; CRLF betikleri bozar.
- Betik yorumları Türkçe, commit mesajları İngilizce ve conventional commit biçiminde.

## Açık konular

- **Dizüstü mü masaüstü mü bilinmiyor.** Intel tümleşik grafik + NVIDIA'lı bir dizüstüyse (hibrit grafik) ek ayar gerekebilir.
- **Kişisel ayarlar (dotfiles), ileride:** Sahibi kullandığı ayarları (fish, fastfetch'in terminalde açılması vb.) sonradan bu repoya ya da ayrı bir repoya koyacak ve oradan yükleyecek. İmaja ya da ilk kuruluma şimdilik bu tür kişisel ayar eklenmiyor. Daha sonra istenirse ilk kurulum ekranı bu repoyu çekebilir; istenmeden yapılmamalı.
- **Snapper (planlandı, sahibi kesin istiyor):** btrfs üzerinde `/var/home` için otomatik anlık görüntü. Henüz eklenmedi.
- **Windows ile çift önyükleme (dual boot) isteniyor.** README'deki kurulum `--wipe` ile bütün diski siliyor; çift önyükleme için `bootc install to-filesystem` ile hazır bir bölüme kurulum yolu yazılmalı. Windows'un EFI bölümü genelde 100 MB ve systemd-boot çekirdek + initramfs'i (NVIDIA ile büyük) oraya koyuyor; yer yetmeyebilir. Sahibinin ayrı bir diski olup olmadığı soruldu.
- **Build süresi:** Önceden ~25 dk'nın ~13–14 dk'sı bootc derlemesiydi. bootc ayrı `nos-bootc` imajına taşındı; günlük build'in ~10 dk'ya inmesi bekleniyor (henüz ölçülmedi). Cache (GitHub Actions önbelleği) bilerek kullanılmadı: Arch imajı sık değiştiği için önbellek sık geçersiz oluyor, kazancı düşük. `nos-bootc` paketinin GitHub'daki görünürlüğü (özel/herkese açık) kontrol edilmedi; ana build giriş yaptığı için ikisi de çalışır.
- **İlk başarılı build (`0cb41f8`):** İmaj oluştu ve yüklendi; imza adımı `COSIGN_PASSWORD` eksik olduğu için düştü (düzeltildi). Günlükte zararsız uyarılar: lint `runtime-deps: chcon` (SELinux yok, sorun değil), `archlinux-keyring` yeniden kurulurken "no secret key" (Docker imajında pacman-key gizli anahtarı yok; paket imza doğrulaması çalışıyor), `.pacnew` dosyaları (`build.sh` sonunda siliniyor). İkinci build (`e0a3386`) imza dahil tamamen başarılı (~25 dk). Sağlayıcı seçimleri: `qt6-multimedia-backend` → `qt6-multimedia-ffmpeg`, `oci-runtime` → `crun` (ikisi de doğru varsayılan); `tessdata` → `tesseract-data-afr` (yanlış, `tesseract-data-eng`/`-tur` listeye eklendi). Ana kurulum ~4.6 GB; en büyükleri `nvidia-utils` (~950 MB), `qt6-webengine` (~280 MB, KDE bileşenlerinin bağımlılığı), `linux`, firmware'ler.
- **Rechunk doğrulaması:** chunkah'ın pacman desteği var (`alpm`) ve veritabanı yerini `pacman.conf`'taki `DBPath`'ten okuyor (bizde `/usr/lib/sysimage/lib/pacman`). Yayınlanan imaj 128 katmanlı ve katman boyutları çok çeşitli (0.7–443 MB), paket bazlı bölmeye uyuyor. Ama günlükte alpm'in bulunduğu henüz görülmedi; bir sonraki "Rechunk image" günlüğünde `alpm` aranmalı. AUR paketleri (Helium) `pacman -U` ile kurulduğu için veritabanında, ayrı bileşen olarak gruplanıyor. bootc, initramfs ve system_files paketsiz dosyalar.
- pacman `--noconfirm` ile sanal paketlerde (ör. `phonon-qt6-backend`) varsayılan sağlayıcıyı seçiyor. İlk build günlüğünden kontrol edilmeli; istenmeyen ya da ağır bir seçim varsa doğru sağlayıcı listeye yazılmalı (`noto-fonts`, `noto-fonts-emoji`, `pipewire-jack` bu yüzden listede).
- Kurulum ISO'su yok: image-template'in ISO'su Fedora'nın Anaconda'sını kullanıyor. Kurulum canlı USB'den `bootc install to-disk` ile.
- İmzalar CI'da atılıyor ama sistem güncellerken doğrulanmıyor (`/etc/containers/policy.json` ayarlanmadı).
- KDE Connect, NVIDIA + Wayland ve ufw kuralları gerçek donanımda denenmedi.
