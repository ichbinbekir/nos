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
- `build_files/bootc/`: bootcrew betikleri ve Apache-2.0 `LICENSE` dosyası. `bootc-rootfs.sh` ve `build-bootc.sh` değiştirildi; değişiklikler dosyaların başında yazıyor.
- `system_files/`: İmaja olduğu gibi kopyalanan dosyalar (SDDM Wayland ayarı, sudoers, resolv.conf tmpfiles).
- `Justfile`: `build`, `rechunk` (chunkah), `disk-image`, `qcow2`.
- `.github/workflows/build.yml`: Push, PR, her gün 04:00 UTC ve elle tetikleme. Build → rechunk → push (`latest`, `YYYYMMDD`, kısa SHA) → cosign imzası (`SIGNING_SECRET` secret'ı tanımlıysa; anahtar şifreli olduğu için şifresi `COSIGN_PASSWORD` secret'ında).
- `.github/workflows/build-disk.yml`: Elle tetikleniyor. Yayınlanmış imajdan sanal makine için qcow2 üretiyor.
- `LICENSE`: Proje MIT. İstisnalar Apache-2.0: `build_files/bootc/` (kendi `LICENSE` dosyası korunmalı) ve Justfile'daki `rechunk` tarifi. Başka projelerden kod alınırsa kaynağı ve lisansı belirtilir, `LICENSE`'taki istisnalar listesine eklenir.
- `cosign.pub`: İmza doğrulama anahtarı. `cosign.key` `.gitignore`'da, asla commit'lenmemeli.

### Build aşamaları

1. `ctx`: `build_files` ve `system_files`. Sadece bind mount ile kullanılır, imaja girmez.
2. `bootc-builder`: bootc'nin en son yayınlanmış sürümünü (`vX.Y.Z` etiketi) SELinux desteği olmadan derler. bootc 1.17'den beri varsayılan olarak libselinux istiyor; Arch'ın resmi depolarında yok. Bu yüzden `CARGO_OPTIONS='--no-default-features --features "install-to-disk pre-6.15"'` kullanılıyor. bootc'ye yeni bir varsayılan özellik eklenirse bu listeye eklenmesi gerekebilir (her crate'in `[features] default`'una bak).
3. `aur-builder`: AUR paketlerini `build` kullanıcısıyla `makepkg` ile derler.
4. `system`: Arch imajı + bootc → pacman yolları `/usr/lib/sysimage`'a taşınır → `build.sh` → `initramfs.sh` → `bootc-rootfs.sh` → `bootc container lint`.

## Teknik notlar

- Paket adlarını Arch'ta doğrula: `https://archlinux.org/packages/search/json/?name=<paket>`. Fedora adları farklı olabiliyor (ör. `kde-connect` → `kdeconnect`, `kwrite` → `kate` paketinin içinde).
- **AUR paketi eklemek:** `aur.sh`'deki `AUR_PACKAGES` listesine ekle. PGP anahtarları `.SRCINFO`'daki `validpgpkeys`'ten otomatik alınıyor.
- **`/opt` imajın içinde gerçek bir dizin.** bootcrew onu `/var/opt`'a yönlendiriyordu; AUR paketleri (Helium) `/opt`'a kurulduğu için değiştirildi.
- **NoExtract:** Resmi Arch Docker imajı man sayfalarını, belgeleri ve çevirileri kurmuyor (`pacman.conf` sonundaki `NoExtract` satırları). `build.sh` bu satırların hepsini siler ve önceden kurulu paketleri yeniden kurar; sonuç normal bir Arch kurulumu gibi olur. Bunu kaldırma, yoksa Türkçe arayüz, klavye ve man sayfaları çalışmaz.
- **ufw:** Build sırasında ufw çalışmıyor; `ufw allow`/`ufw default` kuralları sadece `/etc/ufw` altındaki dosyalara yazıyor. `/etc/ufw/ufw.conf`'ta `ENABLED=yes` ve `ufw.service` açık olunca açılışta uygulanıyor. Gelen bağlantılar kapalı, sadece KDE Connect (1714–1764 TCP/UDP) açık.
- **SDDM Wayland:** `system_files/usr/lib/sddm/sddm.conf.d/10-wayland.conf` giriş ekranını KWin üzerinde Wayland ile çalıştırıyor. sddm paketi Xorg'a bağımlı olduğu için Xorg kuruluyor ama kullanılmıyor.
- **Ağ:** NetworkManager + systemd-resolved (`/etc/resolv.conf` tmpfiles ile yönlendiriliyor). bootcrew'daki `systemd-networkd` kullanılmıyor. `openssh` kurulu ama `sshd` açılmıyor (sadece istemci).
- **İlk açılış:** `/etc/machine-id` `uninitialized` olduğu için systemd-firstboot dil, klavye, saat dilimi ve root şifresini soruyor. Kullanıcı elle oluşturuluyor (README'de anlatılıyor). `wheel` grubu sudo kullanabiliyor.
- **Dosya sistemi:** btrfs (sahibinin tercihi). İmajın içinde değil, kurulumda `bootc install to-disk --filesystem btrfs` ile seçiliyor (README ve Justfile'daki `filesystem`). btrfs desteğinin initramfs'e girmesi için `btrfs-progs` paketinin `initramfs.sh`'den önce kurulu olması gerekiyor; listeden çıkarılmamalı. bootc btrfs'i alt birimler (subvolume) ve anlık görüntü (snapshot) ayarı olmadan, tek bir dosya sistemi olarak kuruyor; sistem için geri alma zaten bootc'de var.
- **bootc lint:** `build.sh` `/run` ve `/tmp` tmpfs'iyle çalışıyor; `/var` ise `bootc-rootfs.sh` tarafından boşaltılıyor.
- Betikler Containerfile'da `bash /ctx/...` ile çalıştırılıyor (Windows'ta yazılan dosyaların çalıştırma izni yok). `.gitattributes` her şeyi LF tutuyor; CRLF betikleri bozar.
- Betik yorumları Türkçe, commit mesajları İngilizce ve conventional commit biçiminde.

## Açık konular

- **Hiç build edilmedi.** İlk CI çalışmasında hata çıkması olası: AUR adımı, NoExtract sonrası yeniden kurulum, ufw'nin build sırasında kural yazması, `bootc container lint`.
- **Dizüstü mü masaüstü mü bilinmiyor.** Intel tümleşik grafik + NVIDIA'lı bir dizüstüyse (hibrit grafik) ek ayar gerekebilir.
- **Snapper (planlandı, sahibi kesin istiyor):** btrfs üzerinde `/var/home` için otomatik anlık görüntü. Henüz eklenmedi.
- **Windows ile çift önyükleme (dual boot) isteniyor.** README'deki kurulum `--wipe` ile bütün diski siliyor; çift önyükleme için `bootc install to-filesystem` ile hazır bir bölüme kurulum yolu yazılmalı. Windows'un EFI bölümü genelde 100 MB ve systemd-boot çekirdek + initramfs'i (NVIDIA ile büyük) oraya koyuyor; yer yetmeyebilir. Sahibinin ayrı bir diski olup olmadığı soruldu.
- **Build süresi:** bootc her build'de kaynaktan derleniyor (10–20 dk). Planlanan iyileştirme: bootc'yi ayrı, küçük bir imaj olarak (ör. `nos-bootc`) sadece yeni bootc sürümünde ve haftada bir derleyip ana build'de `COPY --from` ile kullanmak. Arch kütüphaneleri değişip bootc bozulursa `bootc container lint` adımı bunu yakalar.
- **İlk başarılı build (`0cb41f8`):** İmaj oluştu ve yüklendi; imza adımı `COSIGN_PASSWORD` eksik olduğu için düştü (düzeltildi). Günlükte zararsız uyarılar: lint `runtime-deps: chcon` (SELinux yok, sorun değil), `archlinux-keyring` yeniden kurulurken "no secret key" (Docker imajında pacman-key gizli anahtarı yok; paket imza doğrulaması çalışıyor), `.pacnew` dosyaları (`build.sh` sonunda siliniyor). Sağlayıcı (provider) seçimleri kontrol edilemedi; verilen günlük eksikti.
- pacman `--noconfirm` ile sanal paketlerde (ör. `phonon-qt6-backend`) varsayılan sağlayıcıyı seçiyor. İlk build günlüğünden kontrol edilmeli; istenmeyen ya da ağır bir seçim varsa doğru sağlayıcı listeye yazılmalı (`noto-fonts`, `noto-fonts-emoji`, `pipewire-jack` bu yüzden listede).
- Kurulum ISO'su yok: image-template'in ISO'su Fedora'nın Anaconda'sını kullanıyor. Kurulum canlı USB'den `bootc install to-disk` ile.
- İmzalar CI'da atılıyor ama sistem güncellerken doğrulanmıyor (`/etc/containers/policy.json` ayarlanmadı).
- KDE Connect, NVIDIA + Wayland ve ufw kuralları gerçek donanımda denenmedi.
