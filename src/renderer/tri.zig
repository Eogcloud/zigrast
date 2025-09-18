const std = @import("std");
const math3d = @import("../math/mod.zig");
const Framebuffer = @import("framebuffer.zig").Framebuffer;

pub const ScreenVertex = struct {
    x: f32,
    y: f32,
    z: f32,
    color: u32,

    pub fn init(x: f32, y: f32, z: f32, color: u32) ScreenVertex {
        return ScreenVertex{ .x = x, .y = y, .z = z, .color = color };
    }
};

pub fn drawLine(framebuffer: *Framebuffer, x0: i32, y0: i32, x1: i32, y1: i32, color: u32) void {
    var x0_mut = x0;
    var y0_mut = y0;
    const dx = @as(i32, @intCast(@abs(x1 - x0_mut)));
    const dy = @as(i32, @intCast(@abs(y1 - y0_mut)));
    const sx: i32 = if (x0_mut < x1) 1 else -1;
    const sy: i32 = if (y0_mut < y1) 1 else -1;
    var err = dx - dy;

    while (true) {
        framebuffer.setPixel(x0_mut, y0_mut, color);

        if (x0_mut == x1 and y0_mut == y1) break;

        const e2 = 2 * err;
        if (e2 > -dy) {
            err -= dy;
            x0_mut += sx;
        }
        if (e2 < dx) {
            err += dx;
            y0_mut += sy;
        }
    }
}

pub fn drawTriangleWireframe(framebuffer: *Framebuffer, v0: ScreenVertex, v1: ScreenVertex, v2: ScreenVertex) void {
    const x0 = @as(i32, @intFromFloat(v0.x));
    const y0 = @as(i32, @intFromFloat(v0.y));
    const x1 = @as(i32, @intFromFloat(v1.x));
    const y1 = @as(i32, @intFromFloat(v1.y));
    const x2 = @as(i32, @intFromFloat(v2.x));
    const y2 = @as(i32, @intFromFloat(v2.y));

    drawLine(framebuffer, x0, y0, x1, y1, v0.color);
    drawLine(framebuffer, x1, y1, x2, y2, v1.color);
    drawLine(framebuffer, x2, y2, x0, y0, v2.color);
}

pub fn projectToScreen(vertex: math3d.Vec3, mvp: math3d.Mat4, width: f32, height: f32, color: u32) ?ScreenVertex {
    const clip = mvp.mulVec4(math3d.Vec4.init(vertex.x, vertex.y, vertex.z, 1.0));

    // Check if vertex is behind the camera
    if (clip.w <= 0.0) return null;

    // Perspective divide
    const ndc_x = clip.x / clip.w;
    const ndc_y = clip.y / clip.w;
    var z = clip.z / clip.w;

    // Clamp depth and check for invalid values
    if (!math3d.isFinite(z)) z = 1.0;
    z = math3d.clamp(z, 0.0, 1.0);

    // Convert to screen coordinates
    const screen_x = (ndc_x + 1.0) * 0.5 * width;
    const screen_y = (1.0 - ndc_y) * 0.5 * height; // Flip Y

    return ScreenVertex.init(screen_x, screen_y, z, color);
}
