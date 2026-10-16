# nos

Arch Linux tabanlı, KDE Plasma masaüstüne sahip, **kişisel** bir [bootc](https://github.com/bootc-dev/bootc) imajı.

Sistem bir container imajı olarak GitHub'da build ediliyor ve bilgisayara bu imajdan kuruluyor. Güncellemeler imajın tamamı değiştirilerek geliyor; bir güncelleme sorun çıkarırsa önceki sürüme tek komutla dönülebiliyor.

## Amaç

En temel amaç: **açınca çalışan, rahat kullanılan, hafif bir makine.** Bunun için iki kural var:

1. **Hafif.** Masaüstü ve uygulamalar sadece gerçekten kullanılanlardan oluşuyor; Arch isteğe bağlı bağımlılıkları kendiliğinden kurmadığı için gereksiz paket gelmiyor. Ama aşırıya da kaçılmıyor: git, ssh, man sayfaları gibi Linux'ta normalde bulunan ve arada bir gerekebilecek araçlar yerinde.
2. **Sadece bu projenin sahibine yönelik.** İmaj tek bir bilgisayar ve tek bir kullanıcı için hazırlanıyor: **Intel işlemci** ve **NVIDIA ekran kartı**. Açıkça başka bir donanıma özel olan paketler kurulmuyor.

Bu iki kuralın pratikteki sonuçlarından örnekler:

- İşlemci mikrokodu olarak sadece `intel-ucode` var, `amd-ucode` yok.
- Ekran kartı sürücüsü olarak sadece NVIDIA'nın sürücüsü (`nvidia-open`) var.
- Tarayıcı olarak sadece **Helium** var (AUR'dan, imajın içinde). Başka hiçbir tarayıcı kurulmuyor.
- Güvenlik duvarı olarak firewalld yerine daha basit olan **ufw** kullanılıyor.
- Firmware paketi (`linux-firmware`) ise eksik bir şey çıkmasın diye bütün olarak kuruluyor.

**Başka biri bu imajı olduğu gibi kullanmamalı.** Örneğin AMD işlemcili ya da AMD/Intel ekran kartlı bir bilgisayarda mikrokod ve ekran kartı sürücüsü eksik kalır. Fikri beğendiysen repoyu fork'layıp paket listesini kendi donanımına göre değiştir.

## İçinde ne var

- **Masaüstü:** KDE Plasma (Wayland), SDDM giriş ekranı
- **Uygulamalar:** Konsole, Dolphin, Kate/KWrite, Gwenview, Ark, Spectacle, KDE Connect, Sistem İzleyici, Discover (sadece Flatpak)
- **Tarayıcı:** Helium
- **Araçlar:** fish, fastfetch, git, ssh istemcisi, man sayfaları, Distrobox, Podman, Python, Flatpak (Flathub hazır ekli)

Tam liste: [build_files/build.sh](build_files/build.sh) ve [build_files/aur.sh](build_files/aur.sh).

Başka bir uygulama gerekirse sırasıyla tercih edilen yollar:
1. **Flatpak** (Discover'dan ya da `flatpak install`)
2. **Distrobox** içinde herhangi bir dağıtımın paket yöneticisi
3. Sistemin parçası olması gerekiyorsa paket listesine eklenip imaj yeniden build edilir.

`pacman` ile kurulu sisteme paket kurulamaz; sistem dosyaları salt okunur.

## Kurulum

> [!WARNING]
> Hedef diskteki her şey silinir.

1. BIOS/UEFI ayarlarından **Secure Boot'u kapat.** Önyükleyici ve NVIDIA sürücüsü imzalı değil.
2. Herhangi bir canlı USB ile bilgisayarı aç ve `podman`'i kur.
   - Arch ISO kullanıyorsan açılış menüsünde çekirdek satırının sonuna `cow_spacesize=16G` ekle. Varsayılan 256 MB yazılabilir alan imajı indirmeye yetmiyor. Bu alan RAM'den kullanılıyor.
   - İmaj GitHub'da gizliyse önce `podman login ghcr.io` ile giriş yap.
3. Hedef diskin adını bul (`lsblk`; örnek: `/dev/nvme0n1`) ve kur:
   ```
   sudo podman run --rm --privileged --pid=host \
     --security-opt label=type:unconfined_t \
     -v /var/lib/containers:/var/lib/containers -v /dev:/dev \
     ghcr.io/ichbinbekir/nos:latest \
     bootc install to-disk --composefs-backend --bootloader systemd \
       --filesystem btrfs --wipe /dev/nvme0n1
   ```
4. Yeniden başlat. İlk açılışta bir kurulum ekranı gelir ve sırayla saat dilimi, sistem dili, klavye düzeni, bilgisayar adı, kullanıcı adı, görünen ad ve şifre sorulur (ok tuşları ve Enter ile). Sonda bir özet gösterilir; "Kur" denmeden sistemde hiçbir şey değişmez. Bitince giriş ekranı açılır. Kullanıcının kabuğu fish olarak ayarlanır.

`root` hesabı kilitli; yönetici işleri için `sudo` kullanılır (ilk açılışta oluşturulan kullanıcı `sudo` kullanabilir).

### Sanal makinede denemek (VirtualBox)

1. GitHub'da **Actions → Build disk image → Run workflow** ile biçim olarak `vdi` seç ve çalıştır.
2. Bitince çalışmanın sayfasındaki **Artifacts** bölümünden `nos-vdi`'yi indir ve zip'i aç.
3. VirtualBox'ta yeni bir sanal makine oluştur:
   - Tür: Linux, sürüm: Arch Linux (64-bit)
   - Disk: "Var olan bir sanal sabit disk dosyası kullan" → `disk.vdi`
   - **Sistem → Anakart → "EFI'yi etkinleştir" işaretli olmalı.** Önyükleyici sadece EFI ile çalışıyor; işaretli değilse sistem açılmaz.
   - En az 4 GB RAM, 2 işlemci. Ekran → Grafik denetleyicisi: VMSVGA.
4. Aç. İlk açılış adımları yukarıdaki 4. adımla aynı.

Sanal makinede NVIDIA kartı olmadığı için NVIDIA sürücüsü devreye girmez; ekran VirtualBox'ın kendi grafik sürücüsüyle çalışır, masaüstü biraz yavaş olabilir. Disk 20 GB.

## Kullanım

| İş | Komut |
|---|---|
| Güncelle (yeniden başlatınca uygulanır) | `sudo bootc upgrade` |
| Önceki sürüme dön | `sudo bootc rollback` |
| Hangi sürümdeyim | `sudo bootc status` |
| Otomatik güncellemeyi bu oturumda durdur | `sudo systemctl stop nos-update.timer` |
| Süren güncelleme indirmesini kes | `sudo systemctl stop nos-update.service` |
| Otomatik güncellemeyi kalıcı kapat / aç | `sudo systemctl disable --now nos-update.timer` / `enable --now` |

İmaj her gün otomatik olarak yeniden build ediliyor; Arch paketlerindeki güncellemeler bu yolla geliyor. Sistem de güncellemeleri kendisi kontrol ediyor (açılıştan 10 dakika sonra, sonra her 6 saatte bir): yeni sürümü arka planda indirip hazırlıyor, bilgisayarı yeniden başlatmıyor. Hazırlanan sürüm bir sonraki açılışta devreye giriyor. Elle `sudo bootc upgrade` yapmak gerekmiyor; hemen kontrol etmek istersen kullanabilirsin.

İmajda SSH sunucusu açık değil; `ssh` sadece başka makinelere bağlanmak için var.

## İmza doğrulama

İmajlar [cosign](https://github.com/sigstore/cosign) ile imzalanıyor. Doğrulamak için:

```
cosign verify --key cosign.pub ghcr.io/ichbinbekir/nos:latest
```

## Lisans

[MIT](LICENSE). İstisnalar: [build_files/bootc/](build_files/bootc/) ve Justfile'daki `rechunk` tarifi, alındıkları projelerin lisansı olan Apache-2.0 ile kalıyor.

## Teşekkürler

- [bootcrew/mono](https://github.com/bootcrew/mono): Arch Linux'u bootc ile çalıştırma yöntemi. [build_files/bootc/](build_files/bootc/) altındaki betikler oradan alındı (Apache-2.0).
- [ublue-os/image-template](https://github.com/ublue-os/image-template): Repo düzeni ve build süreci.
