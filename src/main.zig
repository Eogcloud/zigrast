const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});
const perf = @import("platform/perf.zig");
const math3d = @import("math/mod.zig");

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;

pub fn main() !void {
    // Initialize SDL
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.debug.panic("SDL could not initialize! SDL_Error: {s}\n", .{c.SDL_GetError()});
    }
    defer c.SDL_Quit();

    // Create window
    const window = c.SDL_CreateWindow("ZigRast - Software Renderer", SCREEN_WIDTH, SCREEN_HEIGHT, c.SDL_WINDOW_RESIZABLE);
    if (window == null) {
        std.debug.panic("Window could not be created! SDL_Error: {s}\n", .{c.SDL_GetError()});
    }
    defer c.SDL_DestroyWindow(window);

    // Create renderer
    const renderer = c.SDL_CreateRenderer(window, null);
    if (renderer == null) {
        std.debug.panic("Renderer could not be created! SDL_Error: {s}\n", .{c.SDL_GetError()});
    }
    defer c.SDL_DestroyRenderer(renderer);

    // Create framebuffer texture
    const texture = c.SDL_CreateTexture(renderer, c.SDL_PIXELFORMAT_RGBA8888, c.SDL_TEXTUREACCESS_STREAMING, SCREEN_WIDTH, SCREEN_HEIGHT);
    if (texture == null) {
        std.debug.panic("Texture could not be created! SDL_Error: {s}\n", .{c.SDL_GetError()});
    }
    defer c.SDL_DestroyTexture(texture);

    // Allocate framebuffer
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const framebuffer = try allocator.alloc(u32, SCREEN_WIDTH * SCREEN_HEIGHT);
    defer allocator.free(framebuffer);

    // Initialize performance profiler
    var profiler = perf.FrameProfiler.init(allocator);
    defer profiler.deinit();

    // Main loop
    var quit = false;
    var frame: u32 = 0;
    var stats_timer = perf.PerfTimer.start();

    while (!quit) {
        profiler.beginFrame();

        profiler.beginSection("Input");
        var e: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&e)) {
            switch (e.type) {
                c.SDL_EVENT_QUIT => quit = true,
                else => {},
            }
        }
        profiler.endSection("Input");

        profiler.beginSection("Clear");
        clearFramebuffer(framebuffer, 0x000000FF); // Black background
        profiler.endSection("Clear");

        profiler.beginSection("Render");
        drawTestPattern(framebuffer, frame);
        profiler.endSection("Render");

        profiler.beginSection("Upload");
        _ = c.SDL_UpdateTexture(texture, null, framebuffer.ptr, SCREEN_WIDTH * @sizeOf(u32));
        profiler.endSection("Upload");

        profiler.beginSection("Present");
        _ = c.SDL_RenderClear(renderer);
        _ = c.SDL_RenderTexture(renderer, texture, null, null);
        _ = c.SDL_RenderPresent(renderer);
        profiler.endSection("Present");

        profiler.endFrame();
        frame += 1;

        // Print stats every 2 seconds
        if (stats_timer.elapsedMillis() > 2000.0) {
            profiler.printStats();
            stats_timer = perf.PerfTimer.start();
        }

        // Cap framerate (optional - remove for uncapped performance testing)
        c.SDL_Delay(16); // ~60 FPS
    }
}

fn clearFramebuffer(buffer: []u32, color: u32) void {
    for (buffer) |*pixel| {
        pixel.* = color;
    }
}

fn drawTestPattern(buffer: []u32, frame: u32) void {
    // Clear to black
    for (buffer) |*pixel| {
        pixel.* = 0x000000FF;
    }

    // Simple 3D test: rotating cube vertices
    const cube_vertices = [_]math3d.Vec3{
        math3d.Vec3.init(-1, -1, -1), math3d.Vec3.init(1, -1, -1),
        math3d.Vec3.init(1, 1, -1),   math3d.Vec3.init(-1, 1, -1),
        math3d.Vec3.init(-1, -1, 1),  math3d.Vec3.init(1, -1, 1),
        math3d.Vec3.init(1, 1, 1),    math3d.Vec3.init(-1, 1, 1),
    };

    // Create transformation matrices
    const time = @as(f32, @floatFromInt(frame)) * 0.02;
    const rotation_y = math3d.Mat4.rotateY(time);
    const rotation_x = math3d.Mat4.rotateX(time * 0.5);
    const translation = math3d.Mat4.translate(math3d.Vec3.init(0, 0, -5));

    // Combined transformation: translate then rotate
    const model = translation.multiply(rotation_y.multiply(rotation_x));

    // Basic perspective projection
    const aspect = @as(f32, SCREEN_WIDTH) / @as(f32, SCREEN_HEIGHT);
    const perspective = math3d.Mat4.perspective(math3d.degreesToRadians(60), aspect, 0.1, 100.0);

    const mvp = perspective.multiply(model);

    // Project and draw vertices
    for (cube_vertices, 0..) |vertex, i| {
        const projected = mvp.transformVec3(vertex);

        // Convert from normalized device coordinates to screen space
        const screen_x = @as(i32, @intFromFloat((projected.x + 1.0) * 0.5 * SCREEN_WIDTH));
        const screen_y = @as(i32, @intFromFloat((1.0 - projected.y) * 0.5 * SCREEN_HEIGHT));

        // Draw a small cross for each vertex
        if (screen_x >= 2 and screen_x < SCREEN_WIDTH - 2 and
            screen_y >= 2 and screen_y < SCREEN_HEIGHT - 2)
        {
            const colors = [_]u32{ 0xFF0000FF, 0x00FF00FF, 0x0000FFFF, 0xFFFF00FF, 0xFF00FFFF, 0x00FFFFFF, 0xFFFFFFFF, 0x808080FF };
            const color = colors[i];

            // Draw cross pattern (5x5)
            for (0..5) |dy| {
                for (0..5) |dx| {
                    const px = screen_x - 2 + @as(i32, @intCast(dx));
                    const py = screen_y - 2 + @as(i32, @intCast(dy));

                    if (dx == 2 or dy == 2) { // Cross shape
                        const idx = @as(usize, @intCast(py * SCREEN_WIDTH + px));
                        if (idx < buffer.len) {
                            buffer[idx] = color;
                        }
                    }
                }
            }
        }
    }
}
