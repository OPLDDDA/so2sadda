#!/usr/bin/env bash
# macOS only. Injects FridaGadget.dylib into a decrypted Standoff 2 IPA.
set -euo pipefail

IPA="${1:?usage: package-gadget.sh app.ipa}"
GADGET="${2:-$HOME/.cache/frida/gadget-ios.dylib}"
WORK="$(mktemp -d)"
OUT="${IPA%.ipa}-gadget.ipa"
case "$OUT" in
  /*) ;;
  *)  OUT="$PWD/$OUT" ;;
esac
trap 'rm -rf "$WORK"' EXIT

unzip -q "$IPA" -d "$WORK/Payload"
APP="$(find "$WORK/Payload" -maxdepth 1 -name '*.app' -type d | head -n1)"

cp "$GADGET" "$APP/FridaGadget.dylib"
chmod 755 "$APP/FridaGadget.dylib"

if ! command -v insert_dylib >/dev/null 2>&1; then
  echo "missing insert_dylib: brew install insert_dylib" >&2
  exit 1
fi

BIN="$(plutil -extract CFBundleExecutable raw -o - "$APP/Info.plist")"
insert_dylib --inplace --all-yes @executable_path/FridaGadget.dylib "$APP/$BIN"

# FridaGadget config: listen mode so loader.py can attach by name.
cat > "$APP/FridaGadget.config" <<'EOF'
{
  "interaction": {
    "type": "listen",
    "address": "127.0.0.1",
    "port": 27042,
    "on_load": "wait"
  }
}
EOF

cd "$WORK"
zip -qry "$OUT" Payload
echo "written: $OUT"
