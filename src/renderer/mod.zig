// Renderer module exports
pub const Framebuffer = @import("framebuffer.zig").Framebuffer;
pub const Camera = @import("camera.zig").Camera;
pub const Mesh = @import("mesh.zig").Mesh;
pub const Vertex = @import("mesh.zig").Vertex;
pub const Triangle = @import("mesh.zig").Triangle;
pub const text = @import("text.zig");

const std = @import("std");
const math3d = @import("../math/mod.zig");

pub const Renderer = struct {
    framebuffer: Framebuffer,
    camera: Camera,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Renderer {
        const aspect_ratio = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));

        return Renderer{
            .framebuffer = try Framebuffer.init(allocator, width, height),
            .camera = Camera.init(math3d.Vec3.init(0, 0, -5), // position
                math3d.Vec3.ZERO, // target
                60.0, // fov
                aspect_ratio // aspect ratio
            ),
        };
    }

    pub fn deinit(self: *Renderer, allocator: std.mem.Allocator) void {
        self.framebuffer.deinit(allocator);
    }

    pub fn clear(self: *Renderer, color: u32) void {
        self.framebuffer.clear(color);
    }

    pub fn drawPoint(self: *Renderer, point: math3d.Vec3, transform: math3d.Mat4, color: u32, size: u32) void {
        const projected = transform.transformVec3(point);

        // Convert from normalized device coordinates to screen space
        const screen_x = @as(i32, @intFromFloat((projected.x + 1.0) * 0.5 * @as(f32, @floatFromInt(self.framebuffer.width))));
        const screen_y = @as(i32, @intFromFloat((1.0 - projected.y) * 0.5 * @as(f32, @floatFromInt(self.framebuffer.height))));

        // Draw a square of given size
        const half_size = @as(i32, @intCast(size / 2));
        var y: i32 = screen_y - half_size;
        while (y <= screen_y + half_size) : (y += 1) {
            var x: i32 = screen_x - half_size;
            while (x <= screen_x + half_size) : (x += 1) {
                self.framebuffer.setPixel(x, y, color);
            }
        }
    }

    pub fn drawMeshWireframe(self: *Renderer, mesh: Mesh, transform: math3d.Mat4) void {
        // For now, just draw vertices as points
        // We'll implement line drawing in the next step
        for (mesh.vertices) |vertex| {
            self.drawPoint(vertex.position, transform, vertex.color, 3);
        }
    }

    pub fn getViewProjectionMatrix(self: *Renderer) math3d.Mat4 {
        return self.camera.getViewProjectionMatrix();
    }

    pub fn updateCamera(self: *Renderer, time: f32) void {
        // Simple camera animation for demo
        const radius = 8.0;
        const height = 2.0;
        self.camera.position = math3d.Vec3.init(radius * std.math.cos(time * 0.5), height * std.math.sin(time * 0.3), radius * std.math.sin(time * 0.5));
    }
};
