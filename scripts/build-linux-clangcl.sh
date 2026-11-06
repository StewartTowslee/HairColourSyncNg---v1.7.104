#!/usr/bin/env bash
# Cross-build HairColourSyncNg.dll (Windows AMD64, Release, dynamic CRT)
# on Linux with clang-cl + xwin, the toolchain documented by CommonLibSSE-NG
# v11 examples/linux-cross-compile/README.md.
#
# This produces a real PE DLL. It does not run Skyrim and does not verify
# the armor hook against SkyrimSE.exe.
set -euo pipefail

ROOT="${ROOT:-$HOME/hcs-build}"
PLUGIN_SRC="$(cd "$(dirname "$0")/.." && pwd)"
XWIN_VERSION="0.10.0"
XWIN_TARBALL="xwin-${XWIN_VERSION}-x86_64-unknown-linux-musl.tar.gz"
LLVM_MINGW_VERSION="20260826"
LLVM_MINGW_TARBALL="llvm-mingw-${LLVM_MINGW_VERSION}-ucrt-ubuntu-22.04-x86_64.tar.xz"
COMMONLIB_TAG="v11.0.0"
COMMONLIB_COMMIT="94faaed0c60eddd8347767f2d4d29a97c93bde8c"
VCPKG_BASELINE="ee12231b20c95013c6638d845d04c91559a1d1ff"

mkdir -p "$ROOT"
cd "$ROOT"

# MSVC STL 14.44 (the CRT xwin splat pulls by default) rejects Clang older than 19.
pick() {
	local c
	for c in "$@"; do
		if command -v "$c" >/dev/null 2>&1; then
			command -v "$c"
			return 0
		fi
	done
	return 1
}
CLANG="$(pick clang-20 clang-19 clang-18 clang || true)"
LLD="$(pick lld-link-20 lld-link-19 lld-link-18 lld-link || true)"
RC="$(pick llvm-rc-20 llvm-rc-19 llvm-rc-18 llvm-rc || true)"
MT="$(pick llvm-mt-20 llvm-mt-19 llvm-mt-18 llvm-mt || true)"
if [[ -z "$CLANG" || -z "$LLD" || -z "$RC" || -z "$MT" ]]; then
	echo "Need clang>=19, lld-link, llvm-rc and llvm-mt. Ubuntu: apt-get install clang-20 lld-20 llvm-20" >&2
	exit 1
fi
LIB="$(pick llvm-lib-20 llvm-lib-19 llvm-lib-18 llvm-lib || true)"
sudo ln -sfn "$CLANG" /usr/local/bin/clang-cl
sudo ln -sfn "$LLD" /usr/local/bin/lld-link
sudo ln -sfn "$RC" /usr/local/bin/llvm-rc
sudo ln -sfn "$MT" /usr/local/bin/llvm-mt
if [[ -n "$LIB" ]]; then
	sudo ln -sfn "$LIB" /usr/local/bin/llvm-lib
fi

if [[ ! -x "$ROOT/xwin/xwin" ]]; then
	curl -fsSL -o "$XWIN_TARBALL" "https://github.com/Jake-Shadle/xwin/releases/download/${XWIN_VERSION}/${XWIN_TARBALL}"
	curl -fsSL -o "${XWIN_TARBALL}.sha256" "https://github.com/Jake-Shadle/xwin/releases/download/${XWIN_VERSION}/${XWIN_TARBALL}.sha256"
	# Upstream checksum file is "<hash>  <name>" or a bare hash.
	if grep -q "$XWIN_TARBALL" "${XWIN_TARBALL}.sha256"; then
		(cd "$ROOT" && sha256sum -c "${XWIN_TARBALL}.sha256")
	else
		echo "$(awk '{print $1}' "${XWIN_TARBALL}.sha256")  ${XWIN_TARBALL}" | sha256sum -c -
	fi
	mkdir -p "$ROOT/xwin"
	tar -xzf "$XWIN_TARBALL" -C "$ROOT/xwin" --strip-components=1
fi

if [[ ! -d "$ROOT/xwin-out/Windows Kits" && ! -d "$ROOT/xwin-out/VC" ]]; then
	mkdir -p "$ROOT/xwin-cache" "$ROOT/xwin-out"
	"$ROOT/xwin/xwin" --accept-license --http-retry 10 --cache-dir "$ROOT/xwin-cache" splat \
		--output "$ROOT/xwin-out" --include-debug-libs \
		--use-winsysroot-style --preserve-ms-arch-notation
fi

if [[ ! -x "$ROOT/llvm-mingw/bin/x86_64-w64-mingw32-clang++" ]]; then
	curl -fsSL -o "$LLVM_MINGW_TARBALL" \
		"https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_MINGW_VERSION}/${LLVM_MINGW_TARBALL}"
	mkdir -p "$ROOT/llvm-mingw"
	tar -xJf "$LLVM_MINGW_TARBALL" -C "$ROOT/llvm-mingw" --strip-components=1
fi

if [[ ! -d "$ROOT/vcpkg/.git" ]]; then
	git clone --filter=blob:none https://github.com/microsoft/vcpkg.git "$ROOT/vcpkg"
fi
git -C "$ROOT/vcpkg" fetch --filter=blob:none origin "$VCPKG_BASELINE"
git -C "$ROOT/vcpkg" checkout --detach "$VCPKG_BASELINE"
if [[ ! -x "$ROOT/vcpkg/vcpkg" ]]; then
	"$ROOT/vcpkg/bootstrap-vcpkg.sh" -disableMetrics
fi

if ! echo 'int main(){return 0;}' | c++ -x c++ - -o /tmp/hcs-host-cxx-test >/dev/null 2>&1; then
	echo "Host c++ cannot link libstdc++. Install g++-14 and libstdc++-14-dev (Ubuntu's /usr/bin/c++ may be clang and select the newest GCC libdir)." >&2
	exit 1
fi

if [[ ! -d "$ROOT/CommonLibSSE-NG/.git" ]]; then
	git clone --branch "$COMMONLIB_TAG" --depth 1 https://github.com/alandtse/CommonLibSSE-NG.git "$ROOT/CommonLibSSE-NG"
fi
test "$(git -C "$ROOT/CommonLibSSE-NG" rev-parse HEAD)" = "$COMMONLIB_COMMIT"
git -C "$ROOT/CommonLibSSE-NG" submodule update --init extern/openvr
test -f "$ROOT/CommonLibSSE-NG/extern/openvr/lib/win64/openvr_api.lib"

# clang-cl static libraries are archived with llvm-lib. CMake's MSVC platform
# file looks for lib.exe and otherwise records CMAKE_AR-NOTFOUND.
TOOLCHAIN="$ROOT/CommonLibSSE-NG/cmake/toolchain-linux-clangcl.cmake"
if ! grep -q 'llvm-lib' "$TOOLCHAIN"; then
	cat >>"$TOOLCHAIN" <<'EOF'

find_program(_hcs_llvm_lib NAMES llvm-lib llvm-lib-20 llvm-lib-19 llvm-lib-18 REQUIRED)
set(CMAKE_AR "${_hcs_llvm_lib}" CACHE FILEPATH "" FORCE)
EOF
fi

export XWIN_SYSROOT="$ROOT/xwin-out"
export LLVM_MINGW_BIN="$ROOT/llvm-mingw/bin"
export VCPKG_ROOT="$ROOT/vcpkg"
export VCPKG_DISABLE_METRICS=1
export WINEARCH=win64
export WINEPREFIX="$ROOT/wine64"
export WINEDEBUG=-all
export PATH="/usr/local/bin:$ROOT/xwin:$PATH"

cmake -S "$PLUGIN_SRC" -B "$ROOT/plugin-release" -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCOMMONLIBSSE_ROOT="$ROOT/CommonLibSSE-NG" \
	-DCOMMONLIB_ENABLE_IPO=OFF \
	-DBUILD_TESTS=OFF \
	-DCMAKE_MSVC_RUNTIME_LIBRARY='MultiThreadedDLL' \
	-DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
	-DVCPKG_TARGET_TRIPLET=x64-windows-clangcl \
	-DVCPKG_HOST_TRIPLET=x64-linux \
	-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="$ROOT/CommonLibSSE-NG/cmake/toolchain-linux-clangcl.cmake" \
	-DVCPKG_OVERLAY_TRIPLETS="$ROOT/CommonLibSSE-NG/examples/linux-cross-compile/custom-triplets" \
	-DVCPKG_OVERLAY_PORTS="$ROOT/CommonLibSSE-NG/examples/linux-cross-compile/custom-ports" \
	-DXWIN_SYSROOT="$XWIN_SYSROOT" \
	-DCMAKE_MAKE_PROGRAM="$(command -v ninja)" \
	-DCMAKE_AR="$(command -v llvm-lib)" \
	-DVCPKG_APPLOCAL_DEPS=OFF

cmake --build "$ROOT/plugin-release" --target HairColourSyncNg --parallel

echo "DLL: $ROOT/plugin-release/HairColourSyncNg.dll"
file "$ROOT/plugin-release/HairColourSyncNg.dll"
