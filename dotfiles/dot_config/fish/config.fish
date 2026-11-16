# No greeting message on startup.
set fish_greeting

# The user's own programs (e.g. installed with pip/uv/npm).
fish_add_path ~/.local/bin

if status is-interactive
    # Commands to run in interactive sessions can go here
end
