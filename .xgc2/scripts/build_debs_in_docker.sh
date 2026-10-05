#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
output_dir="$root/debs"
while (($#)); do
 case "$1" in --output-dir) output_dir="$2"; shift 2;; *) echo "unknown argument: $1" >&2; exit 1;; esac
done
mkdir -p "$output_dir"; output_dir="$(cd "$output_dir" && pwd)"
image="${XGC2_BUILD_IMAGE:-ghcr.io/xgc-team/xgc2-images/xgc2-build-focal-full-noetic:1.0.0}"
dependency_set_digest="${XGC2_DEPENDENCY_SET_DIGEST:-}"
if [[ -n "$dependency_set_digest" && ! "$dependency_set_digest" =~ ^[0-9a-f]{64}$ ]]; then
 echo "XGC2_DEPENDENCY_SET_DIGEST must be empty or 64 lowercase hex characters" >&2
 exit 1
fi
if [[ -n "${XGC2_APT_OVERLAY_URL:-}" && -z "$dependency_set_digest" ]]; then
 echo "XGC2_APT_OVERLAY_URL requires XGC2_DEPENDENCY_SET_DIGEST" >&2
 exit 1
fi
container_id=""
cleanup() {
 if [[ -n "$container_id" ]]; then docker rm -f "$container_id" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT
container_id="$(docker create --cpus 1 --network bridge \
 --label com.docker.compose.project= --label com.docker.compose.service= --label com.docker.compose.version= \
 --label io.xgc2.local-swarm.agent-count= --label io.xgc2.local-swarm.base-image= \
 --label io.xgc2.local-swarm.image-input-digest= --label io.xgc2.local-swarm.isolation-key= \
 --label io.xgc2.local-swarm.os-profile= --label io.xgc2.local-swarm.product-id= --label io.xgc2.local-swarm.role= \
 -e "PACKAGE_VERSION=${PACKAGE_VERSION:-}" \
 -e "XGC2_APT_OVERLAY_URL=${XGC2_APT_OVERLAY_URL:-}" \
 -e "XGC2_DEPENDENCY_SET_DIGEST=$dependency_set_digest" \
 --mount "type=bind,src=$root,dst=/source,readonly" \
 --entrypoint /bin/bash "$image" -lc '
set -eo pipefail
export DEBIAN_FRONTEND=noninteractive OMP_NUM_THREADS=1 CMAKE_BUILD_PARALLEL_LEVEL=1
# The fixed full-Noetic image owns the toolchain and ROS installation.
for tool in cmake g++ dpkg-shlibdeps dpkg-deb dpkg-query python3 curl; do command -v "$tool"; done
python3 -c "import yaml"
test "$(dpkg-query -W -f="\${Status}" ros-noetic-roscpp)" = "install ok installed"
test -f /opt/ros/noetic/setup.bash
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://xgc2.apt.xiaokang.ink/xgc2-archive-keyring.gpg -o /etc/apt/keyrings/xgc2-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/xgc2-archive-keyring.gpg] https://xgc2.apt.xiaokang.ink focal main" > /etc/apt/sources.list.d/xgc2.list
if [[ -n "$XGC2_APT_OVERLAY_URL" && "$XGC2_DEPENDENCY_SET_DIGEST" != 4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945 ]]; then
 echo "deb [signed-by=/etc/apt/keyrings/xgc2-archive-keyring.gpg] ${XGC2_APT_OVERLAY_URL%/} focal main" > /etc/apt/sources.list.d/00-xgc2-release-train.list
fi
apt-get update
apt-get install -y --no-install-recommends libxgc2-runtime-sdk-dev libxgc2-robotics-interfaces-dev
python3 - /source/.xgc2/product.yml <<"PY_DEPS"
import subprocess,sys,yaml
p=yaml.safe_load(open(sys.argv[1]))
for requirement in p["apt"]["depends"]:
    name, *constraint = requirement.split(" (", 1)
    installed=subprocess.check_output(["dpkg-query","-W","-f=${Version}",name],text=True)
    if constraint:
        operator, required=constraint[0].rstrip(")").split(None,1)
        subprocess.run(["dpkg","--compare-versions",installed,operator,required],check=True)
PY_DEPS
source /opt/ros/noetic/setup.bash
cmake -S /source -B /build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib
cmake --build /build --target xgc_ros_edge -- -j1
DESTDIR=/staged cmake --install /build
bash /source/.xgc2/scripts/package_debs.sh --install-root /staged --output-dir /debs
dpkg -i /debs/libxgc2-ros-runtime-edge_*.deb /debs/libxgc2-ros-runtime-edge-dev_*.deb
ldd /usr/lib/libxgc_ros_edge.so > /debs/installed-ldd.txt
if grep -q "not found" /debs/installed-ldd.txt; then
 echo "installed Edge has unresolved runtime dependencies" >&2
 exit 1
fi
')"
# Build output stays inside this isolated container. Without -a, docker cp
# creates the host output as the invoking user, never container root.
build_status=0
docker start -a "$container_id" || build_status=$?
container_status="$(docker inspect --format '{{.State.ExitCode}}' "$container_id")"
if ((build_status != 0 || container_status != 0)); then
 if ((container_status != 0)); then exit "$container_status"; fi
 exit "$build_status"
fi
docker cp "$container_id:/debs/." "$output_dir/"
docker rm "$container_id" >/dev/null
container_id=""
