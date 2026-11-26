#!/bin/zsh
# Assembles the Samsung and LG apps from the page the iPhone app also serves.
set -e
cd "${0:A:h}"
page=../GameTranslator/Resources/TVReceiver.html
icon=$(ls ../GameTranslator/Resources/Assets.xcassets/AppIcon.appiconset/*.png | head -1)
rm -rf dist/samsung dist/lg
for kind in samsung lg; do
  mkdir -p dist/$kind
  cp $kind/* dist/$kind/
  cp $page dist/$kind/index.html
done
sips -s format png -z 512 512 "$icon" --out dist/samsung/icon.png >/dev/null
sips -s format png -z 80 80 "$icon" --out dist/lg/icon.png >/dev/null
sips -s format png -z 130 130 "$icon" --out dist/lg/largeIcon.png >/dev/null
echo "Ready: TVApps/dist/samsung and TVApps/dist/lg"
command -v tizen >/dev/null && (cd dist/samsung && tizen package -t wgt -o ..) || echo "Samsung: open dist/samsung in Tizen Studio, or run: tizen package -t wgt -s <profile>"
command -v ares-package >/dev/null && ares-package dist/lg -o dist || echo "LG: run: ares-package dist/lg -o dist"
