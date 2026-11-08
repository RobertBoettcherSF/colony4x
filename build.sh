#!/bin/sh
# Native scenario, then WebAssembly, then one self-contained index.html.
# JavaScript in web/template.html only draws. The rules are the Ada package.
set -e
cd "$(dirname "$0")"
mkdir -p obj/native obj/wasm
gprbuild -P colony.gpr -q
./scenario > obj/native-report.txt
echo "Native scenario:"
cat obj/native-report.txt

T=$PWD/toolchain/usr
if [ ! -x "$T/bin/llvm-gcc" ]; then
  echo "Run tools/get-toolchain.sh before the WebAssembly link"
  exit 1
fi
export LD_LIBRARY_PATH="$PWD/toolchain/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
LD=$(command -v wasm-ld || true)
if [ -z "$LD" ]; then
  LD=$(ls /usr/bin/wasm-ld-* 2>/dev/null | tail -1 || true)
fi
if [ -z "$LD" ]; then
  echo "wasm-ld not found (install the lld package)"
  exit 1
fi
rm -rf obj/wasm
mkdir -p obj/wasm
cd obj/wasm
for F in ../../src/colony_names.adb ../../src/colony.adb; do
  echo "cc $F"
  "$T/bin/llvm-gcc" -c --target=wasm32 -O2 -gnat2012 -gnatwa -gnatwe -gnatw.X \
    --RTS="$T/lib/rts-native" -I../../src "$F"
done
clang --target=wasm32 -c -O2 -o wasm_glue.o ../../src/wasm_glue.c
python3 - "$T/lib/rts-native/adalib/libgnat.a" libgnat-wasm.a << 'PY'
import os, subprocess, sys
src, dst = sys.argv[1:]
os.makedirs("rts-pick", exist_ok=True)
members = subprocess.check_output(["ar", "t", src], text=True).split()
keep = []
for i, member in enumerate(members):
    data = subprocess.check_output(["ar", "p", src, member])
    if data.startswith(b"\0asm") or data.startswith(b"BC\xc0\xde"):
        path = os.path.join("rts-pick", f"{i:04d}-{member}")
        open(path, "wb").write(data)
        keep.append(path)
if not keep:
    sys.exit("no wasm objects in libgnat.a")
subprocess.check_call(["ar", "rcs", dst, *keep])
print(f"rts archive {len(keep)} wasm members, skipped {len(members) - len(keep)}")
PY
EXPORTS="c4x_ready c4x_new c4x_act c4x_frame c4x_frame_ptr c4x_text c4x_text_ptr \
c4x_option_count c4x_option c4x_tech_state c4x_stat c4x_set_viewer \
c4x_check_watch c4x_check_manual c4x_check_mechanics"
set --
for E in $EXPORTS; do
  set -- "$@" "--export=$E"
done
"$LD" --no-entry --export-memory --strip-all \
  "$@" \
  -z stack-size=2097152 \
  --initial-memory=33554432 \
  -o colony.wasm \
  *.o \
  libgnat-wasm.a
cd ../..
node tools/smoke_wasm.mjs obj/wasm/colony.wasm > obj/wasm-report.txt
if ! cmp -s obj/native-report.txt obj/wasm-report.txt; then
  echo "Native and WebAssembly reports differ"
  diff -u obj/native-report.txt obj/wasm-report.txt || true
  exit 1
fi
echo "Native and WebAssembly reports match"
node tools/js_mechanics.mjs > obj/js-mechanics.txt
awk '/^(MECH|REST) /' obj/native-report.txt > obj/native-mechanics.txt
if ! cmp -s obj/js-mechanics.txt obj/native-mechanics.txt; then
  echo "JavaScript reference and Ada mechanics differ"
  diff -u obj/js-mechanics.txt obj/native-mechanics.txt || true
  exit 1
fi
echo "JavaScript, native Ada, and WebAssembly mechanics match"
python3 tools/embed.py obj/wasm/colony.wasm web/template.html index.html
echo "Built index.html ($(wc -c < obj/wasm/colony.wasm) bytes of WebAssembly)"
