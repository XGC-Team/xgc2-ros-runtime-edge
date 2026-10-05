#pragma once
#include <xgc-robotics-interfaces/robotics_interfaces_v1.h>

// The same literal field conversion as the generic edge's PVA input.
template<class Message>
inline xgc_position_target_v1 full_position_target(const Message& m, double stamp) {
  xgc_position_target_v1 s{};
  s.stamp = stamp;
  s.position[0]=m.position.x; s.position[1]=m.position.y; s.position[2]=m.position.z;
  s.velocity[0]=m.velocity.x; s.velocity[1]=m.velocity.y; s.velocity[2]=m.velocity.z;
  s.acceleration[0]=m.acceleration_or_force.x; s.acceleration[1]=m.acceleration_or_force.y; s.acceleration[2]=m.acceleration_or_force.z;
  s.yaw=m.yaw; s.yaw_rate=m.yaw_rate; s.type_mask=m.type_mask; s.coordinate_frame=m.coordinate_frame;
  return s;
}
