const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});
const perf = @import("platform/perf.zig");

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
    for (0..SCREEN_HEIGHT) |y| {
        for (0..SCREEN_WIDTH) |x| {
            const index = y * SCREEN_WIDTH + x;

            // Create a simple animated pattern
            const r = @as(u8, @intCast((x + frame) & 0xFF));
            const g = @as(u8, @intCast((y + frame) & 0xFF));
            const b = @as(u8, @intCast(((x + y + frame) / 2) & 0xFF));

            buffer[index] = (@as(u32, r) << 24) | (@as(u32, g) << 16) | (@as(u32, b) << 8) | 0xFF;
        }
    }
}
