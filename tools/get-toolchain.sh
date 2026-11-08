#!/bin/sh
# Ada -> WebAssembly compiler (AdaWebPack 24 = GNAT LLVM) into ./toolchain.
# Same sources as spectrum-analyzer / symmetry-visualizations.
# Needs: rpm2cpio, cpio, curl, and a C++ linker (lld / wasm-ld).
# The compiler binary is itself Ada and needs libgnat-14. If that library
# is not on the system, a local Alire toolchain is installed under toolchain/.
set -e
cd "$(dirname "$0")/.."
mkdir -p toolchain
cd toolchain
F=https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/40/Everything/x86_64/os/Packages
for U in https://github.com/godunko/adawebpack/releases/download/24.0.0/adawebpack-24.0.0-git.fc40.x86_64.rpm \
    $F/l/llvm16-libs-16.0.6-7.fc40.x86_64.rpm \
    $F/c/clang16-libs-16.0.6-5.fc40.x86_64.rpm; do
  echo "Downloading $U"
  curl -fsSL "$U" | rpm2cpio | cpio -idm --quiet
done
mkdir -p lib
cp usr/lib64/llvm16/lib/libLLVM-16.so usr/lib64/llvm16/lib/libclang-cpp.so.16 lib/
if [ ! -e /usr/lib/x86_64-linux-gnu/libedit.so.0 ]; then
  ln -sf /usr/lib/x86_64-linux-gnu/libedit.so.2 lib/libedit.so.0
fi
if ! ldconfig -p 2>/dev/null | grep -q libgnat-14.so; then
  if ! command -v alr >/dev/null 2>&1; then
    echo "Fetching Alire (for libgnat-14)"
    curl -fsSL -o /tmp/alr.bin.zip https://github.com/alire-project/alire/releases/download/v2.1.0/alr-2.1.0-bin-x86_64-linux.zip
    rm -rf /tmp/alr-bin
    unzip -q -o /tmp/alr.bin.zip -d /tmp/alr-bin
    ALR=$(find /tmp/alr-bin -type f -name alr -perm -u+x | head -1)
  else
    ALR=$(command -v alr)
  fi
  "$ALR" -n toolchain --select gnat_native=14.2.1 >/dev/null 2>&1 || true
  "$ALR" -n install --prefix="$PWD/gnat14" gnat_native=14.2.1
  FOUND=$(find gnat14 -name 'libgnat-14.so*' | head -1)
  cp "$FOUND" lib/libgnat-14.so.1
  ln -sf libgnat-14.so.1 lib/libgnat-14.so
fi
rm -rf usr/lib64
echo "Toolchain ready in $PWD"
