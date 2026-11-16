# dotfiles

Personal settings (the ones that go into the home folder). The installer writes them into the
new user's home folder with [chezmoi](https://www.chezmoi.io/); syncing is done with chezmoi too
(see the main README, "Personal settings"). The `.chezmoiroot` file at the root of the repo
tells chezmoi to use only this folder. This README is not copied into the home folder
(`.chezmoiignore`).

File names follow chezmoi's format: a name starting with `dot_` starts with `.` in the home folder.
For example `dot_config/keyd/app.conf` → `~/.config/keyd/app.conf`. A file starting with `symlink_`
becomes a symbolic link, and its content is the link's target (e.g. `dot_config/systemd/user/default.target.wants/symlink_espanso.service`:
enables the espanso service from the image; the same as `systemctl --user enable espanso`).

Contents: fish (`arrow` prompt, greeting off), espanso abbreviations, keyd mapping.

Without the installer: `chezmoi init --apply https://github.com/ichbinbekir/nos.git`.
