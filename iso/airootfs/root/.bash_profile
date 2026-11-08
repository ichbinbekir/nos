# tty1'de kurulum programını başlat; çıkılırsa kabukta kalınır (tekrar: nos-install).
if [[ $(tty) == /dev/tty1 ]]; then
  nos-install
fi
