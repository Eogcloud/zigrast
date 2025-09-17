const std = @import("std");

pub const Framebuffer = struct {
    pixels: []u32,
    width: u32,
    height: u32,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Framebuffer {
        const pixels = try allocator.alloc(u32, width * height);
        return Framebuffer{
            .pixels = pixels,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *Framebuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.pixels);
    }

    pub fn clear(self: *Framebuffer, color: u32) void {
        for (self.pixels) |*pixel| {
            pixel.* = color;
        }
    }

    pub fn setPixel(self: *Framebuffer, x: i32, y: i32, color: u32) void {
        if (x < 0 or y < 0 or x >= self.width or y >= self.height) return;

        const index = @as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x));
        self.pixels[index] = color;
    }

    pub fn getPixel(self: *Framebuffer, x: i32, y: i32) u32 {
        if (x < 0 or y < 0 or x >= self.width or y >= self.height) return 0;

        const index = @as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x));
        return self.pixels[index];
    }

    pub fn isInBounds(self: *Framebuffer, x: i32, y: i32) bool {
        return x >= 0 and y >= 0 and x < self.width and y < self.height;
    }
};
