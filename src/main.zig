const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});
const perf = @import("platform/perf.zig");
const math3d = @import("math/mod.zig");
const renderer = @import("renderer/mod.zig");

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

    // Create SDL renderer
    const sdl_renderer = c.SDL_CreateRenderer(window, null);
    if (sdl_renderer == null) {
        std.debug.panic("Renderer could not be created! SDL_Error: {s}\n", .{c.SDL_GetError()});
    }
    defer c.SDL_DestroyRenderer(sdl_renderer);

    // Create framebuffer texture
    const texture = c.SDL_CreateTexture(sdl_renderer, c.SDL_PIXELFORMAT_RGBA8888, c.SDL_TEXTUREACCESS_STREAMING, SCREEN_WIDTH, SCREEN_HEIGHT);
    if (texture == null) {
        std.debug.panic("Texture could not be created! SDL_Error: {s}\n", .{c.SDL_GetError()});
    }
    defer c.SDL_DestroyTexture(texture);

    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize our software renderer
    var software_renderer = try renderer.Renderer.init(allocator, SCREEN_WIDTH, SCREEN_HEIGHT);
    defer software_renderer.deinit(allocator);

    // Create a test mesh (cube)
    var cube_mesh = try renderer.Mesh.createCube(allocator);
    defer cube_mesh.deinit();

    // Initialize performance profiler
    var profiler = perf.FrameProfiler.init(allocator);
    defer profiler.deinit();

    // Main loop
    var quit = false;
    var frame: u32 = 0;

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
        software_renderer.clear(0x001122FF); // Dark blue background
        profiler.endSection("Clear");

        profiler.beginSection("Render");
        renderScene(&software_renderer, &cube_mesh, frame);
        profiler.endSection("Render");

        profiler.beginSection("Overlay");
        profiler.drawOverlay(&software_renderer.framebuffer, renderer.text);
        profiler.endSection("Overlay");

        profiler.beginSection("Upload");
        _ = c.SDL_UpdateTexture(texture, null, software_renderer.framebuffer.pixels.ptr, SCREEN_WIDTH * @sizeOf(u32));
        profiler.endSection("Upload");

        profiler.beginSection("Present");
        _ = c.SDL_RenderClear(sdl_renderer);
        _ = c.SDL_RenderTexture(sdl_renderer, texture, null, null);
        _ = c.SDL_RenderPresent(sdl_renderer);
        profiler.endSection("Present");

        profiler.endFrame();
        frame += 1;

        // Cap framerate
        c.SDL_Delay(16); // ~60 FPS
    }
}

fn renderScene(software_renderer: *renderer.Renderer, mesh: *renderer.Mesh, frame: u32) void {
    const time = @as(f32, @floatFromInt(frame)) * 0.02;

    // Update camera position (orbiting around the cube)
    software_renderer.updateCamera(time);

    // Create model transformation (rotating cube)
    const rotation_y = math3d.Mat4.rotateY(time);
    const rotation_x = math3d.Mat4.rotateX(time * 0.7);
    const model_transform = rotation_y.multiply(rotation_x);

    // Get view-projection matrix from camera
    const view_projection = software_renderer.getViewProjectionMatrix();

    // Final transformation matrix
    const mvp = view_projection.multiply(model_transform);

    // Draw the mesh (currently just vertices as points)
    software_renderer.drawMeshWireframe(mesh.*, mvp);
}
