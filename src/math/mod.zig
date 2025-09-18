// Math module exports
pub const Vec3 = @import("vec3.zig").Vec3;
pub const Mat4 = @import("mat4.zig").Mat4;
pub const Vec4 = @import("mat4.zig").Vec4;

// Common constants
pub const PI = 3.14159265358979323846;
pub const PI_2 = PI / 2.0;
pub const PI_4 = PI / 4.0;
pub const TWO_PI = PI * 2.0;

// Utility functions
pub fn degreesToRadians(degrees: f32) f32 {
    return degrees * PI / 180.0;
}

pub fn radiansToDegrees(radians: f32) f32 {
    return radians * 180.0 / PI;
}

pub fn clamp(value: f32, min_val: f32, max_val: f32) f32 {
    if (value < min_val) return min_val;
    if (value > max_val) return max_val;
    return value;
}

pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

// Re-export utility from mat4
pub const isFinite = @import("mat4.zig").isFinite;
