cmake_minimum_required(VERSION 3.16)
project(XgcRosRuntimeEdge VERSION 0.1.0 LANGUAGES CXX)
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)
find_package(XgcRuntimeSDK CONFIG REQUIRED)
find_package(catkin REQUIRED COMPONENTS roscpp)
find_package(XgcRoboticsInterfaces CONFIG REQUIRED)

add_library(xgc_ros_edge SHARED src/ros_edge.cpp)
add_library(XgcRosRuntimeEdge::Edge ALIAS xgc_ros_edge)
set_target_properties(xgc_ros_edge PROPERTIES EXPORT_NAME Edge)
target_compile_features(xgc_ros_edge PUBLIC cxx_std_17)
target_include_directories(xgc_ros_edge PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
  ${catkin_INCLUDE_DIRS})
target_link_libraries(xgc_ros_edge PUBLIC XgcRuntime::SDK ${catkin_LIBRARIES})

# Literal field templates have no process state and do not link the Edge DSO.
add_library(xgc_ros_transport INTERFACE)
add_library(XgcRosRuntimeEdge::Transport ALIAS xgc_ros_transport)
set_target_properties(xgc_ros_transport PROPERTIES EXPORT_NAME Transport)
target_include_directories(xgc_ros_transport INTERFACE
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
target_link_libraries(xgc_ros_transport INTERFACE XgcRoboticsInterfaces::Interfaces)

set(config_dir ${CMAKE_INSTALL_DATADIR}/cmake/XgcRosRuntimeEdge)
install(TARGETS xgc_ros_edge EXPORT XgcRosRuntimeEdgeEdgeTargets LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(TARGETS xgc_ros_transport EXPORT XgcRosRuntimeEdgeTransportTargets)
install(EXPORT XgcRosRuntimeEdgeEdgeTargets NAMESPACE XgcRosRuntimeEdge:: DESTINATION ${config_dir})
install(EXPORT XgcRosRuntimeEdgeTransportTargets NAMESPACE XgcRosRuntimeEdge:: DESTINATION ${config_dir})
install(DIRECTORY include/xgc-ros-runtime-edge DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
configure_package_config_file(cmake/XgcRosRuntimeEdgeConfig.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/XgcRosRuntimeEdgeConfig.cmake INSTALL_DESTINATION ${config_dir})
write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/XgcRosRuntimeEdgeConfigVersion.cmake
  VERSION ${PROJECT_VERSION} COMPATIBILITY SameMajorVersion)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/XgcRosRuntimeEdgeConfig.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/XgcRosRuntimeEdgeConfigVersion.cmake DESTINATION ${config_dir})
