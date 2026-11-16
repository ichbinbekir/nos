# Start the installer on tty1; if it exits, you stay in the shell (to rerun: nos-install).
if [[ $(tty) == /dev/tty1 ]]; then
  nos-install
fi
