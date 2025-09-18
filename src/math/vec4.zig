// math/vec4.zig
const std = @import("std");
const Vec3 = @import("vec3.zig").Vec3;

pub const Vec4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub fn init(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn add(self: Vec4, other: Vec4) Vec4 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
            .w = self.w + other.w,
        };
    }

    pub fn scale(self: Vec4, s: f32) Vec4 {
        return .{
            .x = self.x * s,
            .y = self.y * s,
            .z = self.z * s,
            .w = self.w * s,
        };
    }

    /// Divide by w to get normalized device coordinates (NDC).
    /// Returns a Vec3 in the range [-1, 1] if inside the clip volume.
    pub fn perspectiveDivide(self: Vec4) Vec3 {
        if (self.w == 0.0) {
            // Avoid division by zero: return original xyz
            return Vec3.init(self.x, self.y, self.z);
        }
        const inv_w = 1.0 / self.w;
        return Vec3.init(
            self.x * inv_w,
            self.y * inv_w,
            self.z * inv_w,
        );
    }
};
