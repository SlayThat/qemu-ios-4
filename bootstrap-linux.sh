#!/bin/sh
# Linux equivalent of scripts/ios/bootstrap-macos.sh.
#
# Differences from the macOS script:
#   - no --enable-cocoa / --disable-hvf (both are macOS-only concepts)
#   - --enable-vnc and --enable-gtk instead, so IPHONE3G_DISPLAY can be
#     set to vnc=:1 (headless, connect a VNC client) or gtk (if a display
#     server is available in the container)
#   - installs the apt packages QEMU's own configure script needs, plus
#     libgnutls28-dev for the S5L8900 AES accelerator's crypto backend
#     (see AGENTS.md: "Make every QEMU crypto backend exercised by a
#     device qtest an explicit CI package and configure requirement.")
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if command -v apt-get >/dev/null 2>&1; then
    echo "Installing build dependencies via apt..."
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends \
        build-essential \
        git \
        ninja-build \
        pkg-config \
        python3 \
        python3-venv \
        python3-pip \
        libglib2.0-dev \
        libpixman-1-dev \
        libfdt-dev \
        zlib1g-dev \
        libgnutls28-dev \
        libgtk-3-dev \
        libvte-2.91-dev \
        libslirp-dev \
        curl \
        libdigest-sha-perl
else
    echo "apt-get not found; install the QEMU Linux build dependencies" \
         "(ninja, pkg-config, glib, pixman, fdt, gnutls, gtk3, slirp)" \
         "manually before continuing." >&2
fi

if [ -n "${PYTHON:-}" ]; then
    iphone3g_python=$PYTHON
else
    iphone3g_python=
    for candidate in python3.13 python3.12 python3.11 python3; do
        if command -v "$candidate" >/dev/null 2>&1; then
            iphone3g_python=$candidate
            break
        fi
    done
fi

if [ -z "$iphone3g_python" ]; then
    echo "Python 3.11 or newer is required" >&2
    exit 1
fi

if ! "$iphone3g_python" -c '
import sys
if sys.version_info < (3, 11):
    raise SystemExit(1)
'; then
    echo "$iphone3g_python must be Python 3.11 or newer" >&2
    exit 1
fi

cd "$root"
echo "Using $iphone3g_python ($("$iphone3g_python" --version))"
"$iphone3g_python" -m venv .venv
.venv/bin/python -m pip install -r scripts/ios/requirements.txt

./configure \
    --python="$root/.venv/bin/python" \
    --target-list=arm-softmmu \
    --enable-tcg \
    --enable-vnc \
    --enable-gtk \
    --disable-werror \
    --prefix="$root/build/install"
ninja -C build

echo
echo "Build complete. Launch with e.g.:"
echo "  make -C build iphone3g-play IPHONE3G_DISPLAY='vnc=:1'"
echo "then point a VNC client at localhost:5901 (display :1 = port 5900+1)."
