// main.zig
const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});
const perf = @import("platform/perf.zig");
const settings = @import("platform/settings.zig");
const math3d = @import("math/mod.zig");
const ren = @import("renderer/mod.zig");
const mesh = @import("renderer/mesh.zig");
const text = @import("renderer/text.zig");

pub fn main() !void {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load settings
    const launch_settings = settings.LaunchSettings.loadFromFile(allocator, "launchSettings.json") catch |err| {
        std.debug.panic("Failed to load settings: {s}\n", .{@errorName(err)});
    };

    std.debug.print("Starting ZigRast with settings:\n", .{});
    std.debug.print("  Window: {d}x{d} ({})\n", .{ launch_settings.window.width, launch_settings.window.height, launch_settings.window.resizable });
    std.debug.print("  FOV: {d:.1} degrees\n", .{launch_settings.rendering.fov_degrees});
    std.debug.print("  Target FPS: {d}\n", .{launch_settings.performance.target_fps});

    // Initialize SDL
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.debug.panic("SDL could not initialize! SDL_Error: {s}\n", .{c.SDL_GetError()});
    }
    defer c.SDL_Quit();

    // Create window with settings
    const window_flags = if (launch_settings.window.resizable) c.SDL_WINDOW_RESIZABLE else 0;
    const title_slice = try std.fmt.allocPrint(allocator, "{s}", .{launch_settings.window.title});
    defer allocator.free(title_slice);
    const title_z = try allocator.dupeZ(u8, title_slice);
    defer allocator.free(title_z);

    const window = c.SDL_CreateWindow(
        title_z.ptr,
        @as(i32, @intCast(launch_settings.window.width)),
        @as(i32, @intCast(launch_settings.window.height)),
        window_flags,
    );
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

    // Optional VSync (driver-paced presentation)
    _ = c.SDL_SetRenderVSync(sdl_renderer, if (launch_settings.window.vsync) 1 else 0);

    // Create framebuffer texture (nullable so we can recreate on resize)
    var texture: ?*c.SDL_Texture = c.SDL_CreateTexture(
        sdl_renderer,
        c.SDL_PIXELFORMAT_RGBA8888,
        c.SDL_TEXTUREACCESS_STREAMING,
        @as(i32, @intCast(launch_settings.window.width)),
        @as(i32, @intCast(launch_settings.window.height)),
    );
    if (texture == null) {
        std.debug.panic("Texture could not be created! SDL_Error: {s}\n", .{c.SDL_GetError()});
    }
    defer if (texture) |t| c.SDL_DestroyTexture(t);

    // Initialize our software renderer with settings
    var software_renderer = try ren.Renderer.init(allocator, launch_settings.window.width, launch_settings.window.height);
    defer software_renderer.deinit(allocator);

    // Update camera with settings
    software_renderer.camera.fov_radians = math3d.degreesToRadians(launch_settings.rendering.fov_degrees);
    software_renderer.camera.near_plane = launch_settings.rendering.near_plane;
    software_renderer.camera.far_plane = launch_settings.rendering.far_plane;

    // Create a test mesh (cube)
    var cube_mesh = try mesh.Mesh.createCube(allocator);
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
                // Handle window resize: rebuild both software framebuffer and SDL texture
                c.SDL_EVENT_WINDOW_RESIZED => {
                    var new_w_i: i32 = 0;
                    var new_h_i: i32 = 0;
                    _ = c.SDL_GetWindowSize(window, &new_w_i, &new_h_i);

                    const new_w: u32 = @as(u32, @intCast(new_w_i));
                    const new_h: u32 = @as(u32, @intCast(new_h_i));

                    // Re-init software renderer at new size
                    software_renderer.deinit(allocator);
                    software_renderer = try ren.Renderer.init(allocator, new_w, new_h);

                    // Reapply camera settings after re-init
                    software_renderer.camera.fov_radians = math3d.degreesToRadians(launch_settings.rendering.fov_degrees);
                    software_renderer.camera.near_plane = launch_settings.rendering.near_plane;
                    software_renderer.camera.far_plane = launch_settings.rendering.far_plane;

                    // Recreate SDL texture to match new size
                    if (texture) |t| {
                        c.SDL_DestroyTexture(t);
                        texture = null;
                    }
                    texture = c.SDL_CreateTexture(sdl_renderer, c.SDL_PIXELFORMAT_RGBA8888, c.SDL_TEXTUREACCESS_STREAMING, new_w_i, new_h_i);
                    if (texture == null) {
                        std.debug.panic("Texture recreate failed: {s}\n", .{c.SDL_GetError()});
                    }
                },
                else => {},
            }
        }
        profiler.endSection("Input");

        profiler.beginSection("Clear");
        software_renderer.clear(launch_settings.getClearColor());
        profiler.endSection("Clear");

        profiler.beginSection("Render");
        renderScene(&software_renderer, &cube_mesh, frame);
        profiler.endSection("Render");

        if (launch_settings.performance.show_overlay) {
            profiler.beginSection("Overlay");
            profiler.drawOverlay(&software_renderer.framebuffer, text);
            profiler.endSection("Overlay");
        }

        profiler.beginSection("Upload");
        // Use current framebuffer width for pitch (bytes per row)
        const pitch_bytes: i32 = @as(i32, @intCast(software_renderer.framebuffer.width * @sizeOf(u32)));
        _ = c.SDL_UpdateTexture(texture.?, null, software_renderer.framebuffer.pixels.ptr, pitch_bytes);
        profiler.endSection("Upload");

        profiler.beginSection("Present");
        _ = c.SDL_RenderClear(sdl_renderer);
        _ = c.SDL_RenderTexture(sdl_renderer, texture.?, null, null);
        _ = c.SDL_RenderPresent(sdl_renderer);
        profiler.endSection("Present");

        profiler.endFrame();
        frame += 1;

        // Frame rate limiting based on settings (disabled when vsync is enabled)
        const frame_delay = launch_settings.getFrameDelay();
        if (frame_delay > 0) {
            c.SDL_Delay(frame_delay);
        }
    }
}

fn renderScene(software_renderer: *ren.Renderer, mesh_inst: *mesh.Mesh, frame: u32) void {
    const time = @as(f32, @floatFromInt(frame)) * 0.02;
    software_renderer.updateCamera(time);

    const rotation_y = math3d.Mat4.rotateY(time);
    const rotation_x = math3d.Mat4.rotateX(time * 0.7);
    const model_transform = rotation_y.multiply(rotation_x);

    const view_projection = software_renderer.getViewProjectionMatrix();
    const mvp = view_projection.multiply(model_transform);

    software_renderer.drawMeshFlatMesh(mesh_inst, mvp);
}
