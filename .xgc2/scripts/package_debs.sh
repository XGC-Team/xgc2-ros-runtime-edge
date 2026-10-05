#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
install_root=""; output_dir=""
while (($#)); do
 case "$1" in
  --install-root) install_root="$2"; shift 2;;
  --output-dir) output_dir="$2"; shift 2;;
  *) echo "unknown argument: $1" >&2; exit 1;;
 esac
done
[[ -n "$install_root" && -n "$output_dir" ]]
version="${PACKAGE_VERSION:-$(awk -F': *' '/^version:/ {print $2; exit}' "$root/.xgc2/product.yml")}"
[[ -n "$version" ]]
arch="$(dpkg --print-architecture)"
case "$arch" in amd64|arm64) ;; *) echo "unsupported target arch: $arch" >&2; exit 1;; esac
runtime=libxgc2-ros-runtime-edge; development=libxgc2-ros-runtime-edge-dev
[[ -f "$install_root/usr/lib/libxgc_ros_edge.so" ]]
for h in ros_edge.hpp attitude_target_full.hpp pose_stamped.hpp position_target_full.hpp; do
 test -f "$install_root/usr/include/xgc-ros-runtime-edge/$h"
done
for f in XgcRosRuntimeEdgeConfig.cmake XgcRosRuntimeEdgeConfigVersion.cmake XgcRosRuntimeEdgeEdgeTargets.cmake XgcRosRuntimeEdgeTransportTargets.cmake; do
 test -f "$install_root/usr/share/cmake/XgcRosRuntimeEdge/$f"
done
mkdir -p "$output_dir"
staging="$(mktemp -d "$output_dir/.edge-package.XXXXXX")"
trap 'rm -rf -- "$staging"' EXIT
mkdir -p "$staging/$runtime/usr/lib" "$staging/$runtime/DEBIAN" "$staging/$development/usr/include" "$staging/$development/usr/share/cmake" "$staging/$development/DEBIAN" "$staging/debian"
cp -a "$install_root/usr/lib/libxgc_ros_edge.so" "$staging/$runtime/usr/lib/"
cp -a "$install_root/usr/include/xgc-ros-runtime-edge" "$staging/$development/usr/include/"
cp -a "$install_root/usr/share/cmake/XgcRosRuntimeEdge" "$staging/$development/usr/share/cmake/"
# dpkg-shlibdeps reads only this actual staged runtime ELF and real installed
# shlibs metadata. No --ignore-missing-info, guessed SDK/neutral DSO or alias.
printf 'Source: xgc2-ros-runtime-edge\nSection: libs\nPriority: optional\nMaintainer: XGC2 Team\n\nPackage: %s\nArchitecture: any\nDescription: process-local ROS runtime edge\n' "$runtime" > "$staging/debian/control"
(cd "$staging"; dpkg-shlibdeps -O -l/opt/ros/noetic/lib -e"$staging/$runtime/usr/lib/libxgc_ros_edge.so") > "$output_dir/shlibdeps.txt"
dependencies="$(sed -n 's/^shlibs:Depends=//p' "$output_dir/shlibdeps.txt")"
[[ -n "$dependencies" ]]
printf 'Package: %s\nVersion: %s\nArchitecture: %s\nMaintainer: XGC2 Team\nSection: libs\nPriority: optional\nDepends: %s\nDescription: Process-local ROS init and gate runtime\n' "$runtime" "$version" "$arch" "$dependencies" > "$staging/$runtime/DEBIAN/control"
# These are the actual metadata owner's declared BUILD/development requirements,
# not additions to the runtime ELF closure. Runtime itself is exact-version.
development_dependencies="$(python3 - "$root/.xgc2/product.yml" <<'PYDATA'
import sys,yaml
p=yaml.safe_load(open(sys.argv[1]))
print(', '.join(p['apt']['depends']))
PYDATA
)"
printf 'Package: %s\nVersion: %s\nArchitecture: %s\nMaintainer: XGC2 Team\nSection: libdevel\nPriority: optional\nDepends: %s (= %s), %s\nDescription: ROS runtime edge and neutral transport development headers\n' "$development" "$version" "$arch" "$runtime" "$version" "$development_dependencies" > "$staging/$development/DEBIAN/control"
for package in "$runtime" "$development"; do
 mkdir -p "$staging/$package/usr/share/doc/$package"
 cp "$root/LICENSE" "$staging/$package/usr/share/doc/$package/copyright"
 dpkg-deb --build "$staging/$package" "$output_dir/${package}_${version}_${arch}.deb"
done
