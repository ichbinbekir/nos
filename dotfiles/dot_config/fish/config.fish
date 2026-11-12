# Açılışta karşılama yazısı olmasın.
set fish_greeting

# Kullanıcının kendi programları (ör. pip/uv/npm ile kurulanlar).
fish_add_path ~/.local/bin

if status is-interactive
    # Commands to run in interactive sessions can go here
end
