# ROS Runtime Edge

One process-local `libxgc_ros_edge.so` owns ROS initialization and the clock/source output gate. `XgcRosRuntimeEdge::Edge` links only installed Runtime SDK clock primitives and roscpp. `XgcRosRuntimeEdge::Transport` exports the existing neutral attitude, pose and PositionTarget field templates without process state. No simulator/robot owner, ROS timer, controller, SDK client or sensor belongs in this library.

Build from this source with `CMAKE_INSTALL_PREFIX=/usr` and `CMAKE_INSTALL_LIBDIR=lib`. The runtime Debian package contains the sole `/usr/lib/libxgc_ros_edge.so`; the development package contains four headers under `xgc-ros-runtime-edge` and `share/cmake/XgcRosRuntimeEdge`. The development package depends on the exact runtime version. Runtime dependencies come from strict `dpkg-shlibdeps` on the staged ELF. SDK and neutral header requirements are development dependencies.

This replaces the old adapters-owned Edge/Helpers exports and payload in the same adoption. No alias, second compiled gate or old-package bootstrap is provided. Simulator-specific owners/DTOs remain solely in Lightweight Simulator; `ros_slice` stays private to its generic ROS consumer.

The source/recipe is a new owning declaration. Private selected-build ELF evidence does not establish a produced Debian package, installed consumer, compatible APT floor, multiarchitecture build, station readiness or release.
