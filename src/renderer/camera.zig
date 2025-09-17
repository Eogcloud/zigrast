const std = @import("std");
const math3d = @import("../math/mod.zig");

pub const Camera = struct {
    position: math3d.Vec3,
    target: math3d.Vec3,
    up: math3d.Vec3,
    fov_radians: f32,
    aspect_ratio: f32,
    near_plane: f32,
    far_plane: f32,

    pub fn init(position: math3d.Vec3, target: math3d.Vec3, fov_degrees: f32, aspect_ratio: f32) Camera {
        return Camera{
            .position = position,
            .target = target,
            .up = math3d.Vec3.UP,
            .fov_radians = math3d.degreesToRadians(fov_degrees),
            .aspect_ratio = aspect_ratio,
            .near_plane = 0.1,
            .far_plane = 100.0,
        };
    }

    pub fn getViewMatrix(self: Camera) math3d.Mat4 {
        return math3d.Mat4.lookAt(self.position, self.target, self.up);
    }

    pub fn getProjectionMatrix(self: Camera) math3d.Mat4 {
        return math3d.Mat4.perspective(self.fov_radians, self.aspect_ratio, self.near_plane, self.far_plane);
    }

    pub fn getViewProjectionMatrix(self: Camera) math3d.Mat4 {
        return self.getProjectionMatrix().multiply(self.getViewMatrix());
    }

    pub fn setAspectRatio(self: *Camera, aspect_ratio: f32) void {
        self.aspect_ratio = aspect_ratio;
    }

    pub fn movePosition(self: *Camera, delta: math3d.Vec3) void {
        self.position = self.position.add(delta);
    }

    pub fn moveTarget(self: *Camera, delta: math3d.Vec3) void {
        self.target = self.target.add(delta);
    }

    pub fn orbitAroundTarget(self: *Camera, delta_yaw: f32, delta_pitch: f32) void {
        const offset = self.position.sub(self.target);
        const distance = offset.length();

        // Convert to spherical coordinates, apply rotation, convert back
        const current_yaw = std.math.atan2(offset.z, offset.x);
        const current_pitch = std.math.asin(offset.y / distance);

        const new_yaw = current_yaw + delta_yaw;
        const new_pitch = math3d.clamp(current_pitch + delta_pitch, -math3d.PI_2 + 0.1, math3d.PI_2 - 0.1);

        const new_offset = math3d.Vec3.init(
            distance * std.math.cos(new_pitch) * std.math.cos(new_yaw),
            distance * std.math.sin(new_pitch),
            distance * std.math.cos(new_pitch) * std.math.sin(new_yaw),
        );

        self.position = self.target.add(new_offset);
    }
};
