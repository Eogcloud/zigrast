const std = @import("std");
const math = std.math;

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub const ZERO = Vec3{ .x = 0, .y = 0, .z = 0 };
    pub const ONE = Vec3{ .x = 1, .y = 1, .z = 1 };
    pub const UP = Vec3{ .x = 0, .y = 1, .z = 0 };
    pub const RIGHT = Vec3{ .x = 1, .y = 0, .z = 0 };
    pub const FORWARD = Vec3{ .x = 0, .y = 0, .z = -1 };

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return Vec3{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return Vec3{
            .x = self.x - other.x,
            .y = self.y - other.y,
            .z = self.z - other.z,
        };
    }

    pub fn mul(self: Vec3, scalar: f32) Vec3 {
        return Vec3{
            .x = self.x * scalar,
            .y = self.y * scalar,
            .z = self.z * scalar,
        };
    }

    pub fn div(self: Vec3, scalar: f32) Vec3 {
        return Vec3{
            .x = self.x / scalar,
            .y = self.y / scalar,
            .z = self.z / scalar,
        };
    }

    pub fn dot(self: Vec3, other: Vec3) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn cross(self: Vec3, other: Vec3) Vec3 {
        return Vec3{
            .x = self.y * other.z - self.z * other.y,
            .y = self.z * other.x - self.x * other.z,
            .z = self.x * other.y - self.y * other.x,
        };
    }

    pub fn length(self: Vec3) f32 {
        return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn lengthSquared(self: Vec3) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn normalize(self: Vec3) Vec3 {
        const len = self.length();
        if (len == 0) return Vec3.ZERO;
        return self.div(len);
    }

    pub fn distance(self: Vec3, other: Vec3) f32 {
        return self.sub(other).length();
    }

    pub fn lerp(self: Vec3, other: Vec3, t: f32) Vec3 {
        return Vec3{
            .x = self.x + (other.x - self.x) * t,
            .y = self.y + (other.y - self.y) * t,
            .z = self.z + (other.z - self.z) * t,
        };
    }

    pub fn print(self: Vec3) void {
        std.debug.print("Vec3({d:.3}, {d:.3}, {d:.3})", .{ self.x, self.y, self.z });
    }
};

// Tests
test "vec3 basic operations" {
    const a = Vec3.init(1, 2, 3);
    const b = Vec3.init(4, 5, 6);

    const sum = a.add(b);
    try std.testing.expectEqual(@as(f32, 5), sum.x);
    try std.testing.expectEqual(@as(f32, 7), sum.y);
    try std.testing.expectEqual(@as(f32, 9), sum.z);

    const dot_product = a.dot(b);
    try std.testing.expectEqual(@as(f32, 32), dot_product); // 1*4 + 2*5 + 3*6 = 32
}

test "vec3 normalize" {
    const v = Vec3.init(3, 4, 0);
    const normalized = v.normalize();
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), normalized.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), normalized.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), normalized.z, 0.001);
}
