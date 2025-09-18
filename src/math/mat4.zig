const std = @import("std");
const math = std.math;
const Vec3 = @import("vec3.zig").Vec3;
const Vec4 = @import("vec4.zig").Vec4;

pub const Mat4 = struct {
    // Row-major order: m[row][col]
    m: [4][4]f32,

    pub const IDENTITY = Mat4{
        .m = .{
            .{ 1, 0, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 1, 0 },
            .{ 0, 0, 0, 1 },
        },
    };

    pub const ZERO = Mat4{
        .m = .{
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
    };

    pub fn init() Mat4 {
        return IDENTITY;
    }

    pub fn multiply(self: Mat4, other: Mat4) Mat4 {
        var result = ZERO;

        for (0..4) |i| {
            for (0..4) |j| {
                for (0..4) |k| {
                    result.m[i][j] += self.m[i][k] * other.m[k][j];
                }
            }
        }

        return result;
    }

    pub fn translate(translation: Vec3) Mat4 {
        return Mat4{
            .m = .{
                .{ 1, 0, 0, translation.x },
                .{ 0, 1, 0, translation.y },
                .{ 0, 0, 1, translation.z },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn scale(s: Vec3) Mat4 {
        return Mat4{
            .m = .{
                .{ s.x, 0, 0, 0 },
                .{ 0, s.y, 0, 0 },
                .{ 0, 0, s.z, 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn rotateX(angle_radians: f32) Mat4 {
        const c = math.cos(angle_radians);
        const s = math.sin(angle_radians);

        return Mat4{
            .m = .{
                .{ 1, 0, 0, 0 },
                .{ 0, c, -s, 0 },
                .{ 0, s, c, 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn rotateY(angle_radians: f32) Mat4 {
        const c = math.cos(angle_radians);
        const s = math.sin(angle_radians);

        return Mat4{
            .m = .{
                .{ c, 0, s, 0 },
                .{ 0, 1, 0, 0 },
                .{ -s, 0, c, 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn rotateZ(angle_radians: f32) Mat4 {
        const c = math.cos(angle_radians);
        const s = math.sin(angle_radians);

        return Mat4{
            .m = .{
                .{ c, -s, 0, 0 },
                .{ s, c, 0, 0 },
                .{ 0, 0, 1, 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn perspective(fov_radians: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const f = 1.0 / math.tan(fov_radians / 2.0);
        const range_inv = 1.0 / (near - far);

        return Mat4{
            .m = .{
                .{ f / aspect, 0, 0, 0 },
                .{ 0, f, 0, 0 },
                .{ 0, 0, (near + far) * range_inv, 2.0 * near * far * range_inv },
                .{ 0, 0, -1, 0 },
            },
        };
    }

    pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
        const forward = target.sub(eye).normalize();
        const right = forward.cross(up).normalize();
        const new_up = right.cross(forward);

        return Mat4{
            .m = .{
                .{ right.x, right.y, right.z, -right.dot(eye) },
                .{ new_up.x, new_up.y, new_up.z, -new_up.dot(eye) },
                .{ -forward.x, -forward.y, -forward.z, forward.dot(eye) },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn transformVec3(self: Mat4, v: Vec3) Vec3 {
        const x = self.m[0][0] * v.x + self.m[0][1] * v.y + self.m[0][2] * v.z + self.m[0][3];
        const y = self.m[1][0] * v.x + self.m[1][1] * v.y + self.m[1][2] * v.z + self.m[1][3];
        const z = self.m[2][0] * v.x + self.m[2][1] * v.y + self.m[2][2] * v.z + self.m[2][3];
        const w = self.m[3][0] * v.x + self.m[3][1] * v.y + self.m[3][2] * v.z + self.m[3][3];

        return Vec3{
            .x = x / w,
            .y = y / w,
            .z = z / w,
        };
    }

    pub fn print(self: Mat4) void {
        std.debug.print("Mat4:\n", .{});
        for (0..4) |i| {
            std.debug.print("  [{d:.3} {d:.3} {d:.3} {d:.3}]\n", .{ self.m[i][0], self.m[i][1], self.m[i][2], self.m[i][3] });
        }
    }

    pub fn multiplyVec3W(self: Mat4, v: Vec3, w: f32) Vec4 {
        return Vec4.init(
            self.m[0][0] * v.x + self.m[0][1] * v.y + self.m[0][2] * v.z + self.m[0][3] * w,
            self.m[1][0] * v.x + self.m[1][1] * v.y + self.m[1][2] * v.z + self.m[1][3] * w,
            self.m[2][0] * v.x + self.m[2][1] * v.y + self.m[2][2] * v.z + self.m[2][3] * w,
            self.m[3][0] * v.x + self.m[3][1] * v.y + self.m[3][2] * v.z + self.m[3][3] * w,
        );
    }
};

test "mat4 identity" {
    const identity = Mat4.IDENTITY;
    const v = Vec3.init(1, 2, 3);
    const transformed = identity.transformVec3(v);

    try std.testing.expectApproxEqAbs(@as(f32, 1), transformed.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2), transformed.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3), transformed.z, 0.001);
}

test "mat4 translation" {
    const translation = Mat4.translate(Vec3.init(5, 10, 15));
    const v = Vec3.init(1, 2, 3);
    const transformed = translation.transformVec3(v);

    try std.testing.expectApproxEqAbs(@as(f32, 6), transformed.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 12), transformed.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 18), transformed.z, 0.001);
}
