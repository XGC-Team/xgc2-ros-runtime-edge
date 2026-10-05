#pragma once
#include <xgc-robotics-interfaces/robotics_interfaces_v1.h>

// Literal native pose -> PoseStamped-like transport fields; caller owns frame.
template<class Message>
inline void assign_pose_stamped(const xgc_pose_v1& s, Message* m) {
  m->header.stamp.fromSec(s.stamp);
  m->pose.position.x = s.position[0];
  m->pose.position.y = s.position[1];
  m->pose.position.z = s.position[2];
  m->pose.orientation.w = s.q_wxyz[0];
  m->pose.orientation.x = s.q_wxyz[1];
  m->pose.orientation.y = s.q_wxyz[2];
  m->pose.orientation.z = s.q_wxyz[3];
}
