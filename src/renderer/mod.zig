// src/renderer/mod.zig
const std = @import("std");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const math = @import("../math/mod.zig");
const tri = @import("tri.zig");
const Camera = @import("camera.zig").Camera;
const Mesh = @import("mesh.zig").Mesh;

pub const Renderer = struct {
    framebuffer: Framebuffer,
    camera: Camera,
    zbuffer: []f32,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Renderer {
        var fb = try Framebuffer.init(allocator, width, height);
        errdefer fb.deinit(allocator);

        const zcount = @as(usize, width) * @as(usize, height);
        const zbuf = try allocator.alloc(f32, zcount);
        errdefer allocator.free(zbuf);
        for (zbuf) |*z| z.* = std.math.inf(f32);

        const aspect = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));

        return .{
            .framebuffer = fb,
            .camera = Camera{
                .position = math.Vec3{ .x = 0, .y = 0, .z = 3 },
                .target = math.Vec3{ .x = 0, .y = 0, .z = 0 },
                .up = math.Vec3{ .x = 0, .y = 1, .z = 0 },
                .fov_radians = math.degreesToRadians(60.0),
                .aspect_ratio = aspect,
                .near_plane = 0.1,
                .far_plane = 100.0,
            },
            .zbuffer = zbuf,
        };
    }

    pub fn deinit(self: *Renderer, allocator: std.mem.Allocator) void {
        allocator.free(self.zbuffer);
        self.framebuffer.deinit(allocator);
    }

    pub fn clear(self: *Renderer, color: u32) void {
        self.framebuffer.clear(color);
        for (self.zbuffer) |*z| z.* = std.math.inf(f32);
    }

    // --- projection to screen (unchanged) ---
    fn projectToScreen(self: *Renderer, mvp: math.Mat4, p: math.Vec3) struct { x: i32, y: i32, z: f32 } {
        const clip = mvp.multiplyVec4(.{ .x = p.x, .y = p.y, .z = p.z, .w = 1.0 });
        const invw = 1.0 / clip.w;
        const ndc_x: f32 = clip.x * invw;
        const ndc_y: f32 = clip.y * invw;
        const ndc_z: f32 = clip.z * invw;

        const half_w: f32 = @as(f32, @floatFromInt(self.framebuffer.width)) * 0.5;
        const half_h: f32 = @as(f32, @floatFromInt(self.framebuffer.height)) * 0.5;

        const sx = @as(i32, @intFromFloat(@floor((ndc_x * half_w) + half_w)));
        const sy = @as(i32, @intFromFloat(@floor((-ndc_y * half_h) + half_h)));
        const sz: f32 = (ndc_z * 0.5) + 0.5; // [0,1]

        return .{ .x = sx, .y = sy, .z = sz };
    }

    pub fn drawTriangleFlatScreen(self: *Renderer, v0: tri.ScreenVertex, v1: tri.ScreenVertex, v2: tri.ScreenVertex, color: u32) void {
        const tgt: tri.RasterTarget = .{
            .width = @as(i32, @intCast(self.framebuffer.width)),
            .height = @as(i32, @intCast(self.framebuffer.height)),
            .pixels = self.framebuffer.pixels.ptr,
            .zbuffer = self.zbuffer.ptr,
        };
        tri.drawTriangleFlat(tgt, v0, v1, v2, color);
    }

    /// DEBUG: draw triangle without Z-test
    pub fn drawTriangleFlatScreenNoZ(self: *Renderer, v0: tri.ScreenVertex, v1: tri.ScreenVertex, v2: tri.ScreenVertex, color: u32) void {
        const tgt: tri.RasterTarget = .{
            .width = @as(i32, @intCast(self.framebuffer.width)),
            .height = @as(i32, @intCast(self.framebuffer.height)),
            .pixels = self.framebuffer.pixels.ptr,
            .zbuffer = self.zbuffer.ptr,
        };
        tri.drawTriangleFlatNoZ(tgt, v0, v1, v2, color);
    }

    /// Draw a Mesh with flat shading (first vertex color).
    pub fn drawMeshFlatMesh(self: *Renderer, m: *const Mesh, mvp: math.Mat4) void {
        for (m.triangles) |t| {
            const idx0 = @as(usize, t.indices[0]);
            const idx1 = @as(usize, t.indices[1]);
            const idx2 = @as(usize, t.indices[2]);

            const v0 = m.vertices[idx0];
            const v1 = m.vertices[idx1];
            const v2 = m.vertices[idx2];

            const s0 = self.projectToScreen(mvp, v0.position);
            const s1 = self.projectToScreen(mvp, v1.position);
            const s2 = self.projectToScreen(mvp, v2.position);

            const color = v0.color;

            self.drawTriangleFlatScreen(
                .{ .x = s0.x, .y = s0.y, .z = s0.z },
                .{ .x = s1.x, .y = s1.y, .z = s1.z },
                .{ .x = s2.x, .y = s2.y, .z = s2.z },
                color,
            );
        }
    }

    /// DEBUG: draw all mesh vertices as 3×3 crosses in screen space.
    pub fn drawMeshDebugPoints(self: *Renderer, m: *const Mesh, mvp: math.Mat4, color: u32) void {
        const w = @as(i32, @intCast(self.framebuffer.width));
        const h = @as(i32, @intCast(self.framebuffer.height));
        for (m.vertices) |v| {
            const s = self.projectToScreen(mvp, v.position);
            // draw a small cross
            for ([-1, 0, 1]) |dx| {
                const xx = s.x + dx;
                if (xx < 0 or xx >= w) continue;
                if (s.y >= 0 and s.y < h) self.framebuffer.setPixel(xx, s.y, color);
            }
            for ([-1, 0, 1]) |dy| {
                const yy = s.y + dy;
                if (yy < 0 or yy >= h) continue;
                if (s.x >= 0 and s.x < w) self.framebuffer.setPixel(s.x, yy, color);
            }
        }
    }

    pub fn updateCamera(self: *Renderer, time: f32) void {
        const r: f32 = 5.0;
        const y: f32 = 2.0;
        const cx = r * std.math.cos(time);
        const cz = r * std.math.sin(time);
        self.camera.target = math.Vec3.init(0, 0, 0);
        self.camera.position = math.Vec3.init(cx, y, cz);
        self.camera.up = math.Vec3.UP;
        self.camera.aspect_ratio =
            @as(f32, @floatFromInt(self.framebuffer.width)) /
            @as(f32, @floatFromInt(self.framebuffer.height));
    }

    pub fn getViewProjectionMatrix(self: *Renderer) math.Mat4 {
        return self.camera.getViewProjectionMatrix();
    }
};
