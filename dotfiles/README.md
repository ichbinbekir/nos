# dotfiles

Kişisel ayarlar (ev klasörüne gidenler). Kurulum programı bunları
[chezmoi](https://www.chezmoi.io/) ile yeni kullanıcının ev klasörüne yazıyor; eşitleme de
chezmoi ile (bkz. ana README, "Kişisel ayarlar"). Reponun kökündeki `.chezmoiroot`
chezmoi'ye sadece bu klasörü kullanmasını söylüyor. Bu README ev klasörüne kopyalanmaz
(`.chezmoiignore`).

Dosya adları chezmoi'nin biçiminde: `dot_` ile başlayan ad ev klasöründe `.` ile başlar.
Örneğin `dot_config/keyd/app.conf` → `~/.config/keyd/app.conf`.

Kurulum programı kullanılmadan: `chezmoi init --apply https://github.com/ichbinbekir/nos.git`.
