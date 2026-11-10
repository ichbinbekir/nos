# dotfiles

Kişisel ayarlar (ev klasörüne gidenler). Şimdilik sadece saklanıyor; ileride kurulum
programı bunları [chezmoi](https://www.chezmoi.io/) ile yeni kullanıcının ev klasörüne
yazacak, eşitleme de chezmoi ile olacak.

Dosya adları chezmoi'nin biçiminde: `dot_` ile başlayan ad ev klasöründe `.` ile başlar.
Örneğin `dot_config/keyd/app.conf` → `~/.config/keyd/app.conf`.

Şimdilik elle kopyalamak için:

```
cp dotfiles/dot_config/keyd/app.conf ~/.config/keyd/app.conf
```
