// platform/perf.zig
const std = @import("std");

pub const PerfTimer = struct {
    start_time: i128,

    pub fn start() PerfTimer {
        return PerfTimer{ .start_time = std.time.nanoTimestamp() };
    }

    pub fn elapsedNanos(self: PerfTimer) i128 {
        return std.time.nanoTimestamp() - self.start_time;
    }

    pub fn elapsedMicros(self: PerfTimer) f64 {
        return @as(f64, @floatFromInt(self.elapsedNanos())) / 1_000.0;
    }

    pub fn elapsedMillis(self: PerfTimer) f64 {
        return @as(f64, @floatFromInt(self.elapsedNanos())) / 1_000_000.0;
    }
};

pub const FrameProfiler = struct {
    frame_times: [60]f64,
    frame_index: usize,
    frame_timer: PerfTimer,
    section_timers: std.StringHashMap(PerfTimer),
    section_times: std.StringHashMap(f64),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FrameProfiler {
        return FrameProfiler{
            .frame_times = [_]f64{16.67} ** 60, // Initialize to ~60 FPS
            .frame_index = 0,
            .frame_timer = PerfTimer.start(),
            .section_timers = std.StringHashMap(PerfTimer).init(allocator),
            .section_times = std.StringHashMap(f64).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FrameProfiler) void {
        self.section_timers.deinit();
        self.section_times.deinit();
    }

    pub fn beginFrame(self: *FrameProfiler) void {
        self.frame_timer = PerfTimer.start();
    }

    pub fn endFrame(self: *FrameProfiler) void {
        const frame_time = self.frame_timer.elapsedMillis();
        self.frame_times[self.frame_index] = frame_time;
        self.frame_index = (self.frame_index + 1) % self.frame_times.len;
    }

    pub fn beginSection(self: *FrameProfiler, name: []const u8) void {
        self.section_timers.put(name, PerfTimer.start()) catch {};
    }

    pub fn endSection(self: *FrameProfiler, name: []const u8) void {
        if (self.section_timers.get(name)) |timer| {
            const elapsed = timer.elapsedMillis();
            self.section_times.put(name, elapsed) catch {};
        }
    }

    pub fn getAverageFrameTime(self: *FrameProfiler) f64 {
        var total: f64 = 0;
        for (self.frame_times) |time| total += time;
        return total / @as(f64, @floatFromInt(self.frame_times.len));
    }

    pub fn getAverageFPS(self: *FrameProfiler) f64 {
        return 1000.0 / self.getAverageFrameTime();
    }

    pub fn getSectionTime(self: *FrameProfiler, name: []const u8) f64 {
        return self.section_times.get(name) orelse 0.0;
    }

    pub fn printStats(self: *FrameProfiler) void {
        const avg_frame = self.getAverageFrameTime();
        const fps = self.getAverageFPS();

        std.debug.print("\n=== Performance Stats ===\n", .{});
        std.debug.print("Frame Time: {d:.2}ms | FPS: {d:.1}\n", .{ avg_frame, fps });

        var it = self.section_times.iterator();
        while (it.next()) |entry| {
            const percentage = if (avg_frame > 0.0) (entry.value_ptr.* / avg_frame) * 100.0 else 0.0;
            std.debug.print("{s}: {d:.2}ms ({d:.1}%)\n", .{ entry.key_ptr.*, entry.value_ptr.*, percentage });
        }
        std.debug.print("========================\n\n", .{});
    }

    /// Draws a scaled overlay using renderer/text.zig helpers.
    /// `text_module` must export drawStringScaled/drawNumberScaled/drawFloatScaled.
    pub fn drawOverlay(self: *FrameProfiler, framebuffer: anytype, text_module: anytype) void {
        const avg_frame = self.getAverageFrameTime();
        const fps = self.getAverageFPS();

        // Scale factor for readability (2 or 3 works well on 1080p).
        const overlay_scale: u32 = 3;

        const overlay_x = 10;
        var overlay_y: i32 = 10;

        const text_color = 0xFFFFFFFF; // White
        const bg_color = 0x000000DD; // Semi-transparent black

        // Background box size scaled from previous constants (120x50 base).
        const box_width = @as(i32, 120 * @as(i32, @intCast(overlay_scale)));
        const box_height = @as(i32, 50 * @as(i32, @intCast(overlay_scale)));

        // Draw background box
        var dy: i32 = 0;
        while (dy < box_height) : (dy += 1) {
            var dx: i32 = 0;
            while (dx < box_width) : (dx += 1) {
                framebuffer.setPixel(overlay_x + dx, overlay_y + dy, bg_color);
            }
        }

        // Line/advance metrics derived from text metrics
        const line_height = (8 + 4) * @as(i32, @intCast(overlay_scale)); // FONT_HEIGHT(8) + extra

        // Draw FPS with label
        text_module.drawStringScaled(framebuffer, "FPS", overlay_x + 5 * @as(i32, @intCast(overlay_scale)), overlay_y + 5 * @as(i32, @intCast(overlay_scale)), text_color, overlay_scale);
        const fps_rounded = @as(u32, @intFromFloat(@round(fps)));
        text_module.drawNumberScaled(framebuffer, fps_rounded, overlay_x + 40 * @as(i32, @intCast(overlay_scale)), overlay_y + 5 * @as(i32, @intCast(overlay_scale)), text_color, overlay_scale);

        overlay_y += line_height;

        // Draw frame time with label
        text_module.drawStringScaled(framebuffer, "MS", overlay_x + 5 * @as(i32, @intCast(overlay_scale)), overlay_y + 5 * @as(i32, @intCast(overlay_scale)), text_color, overlay_scale);
        text_module.drawFloatScaled(framebuffer, @as(f32, @floatCast(avg_frame)), 1, overlay_x + 40 * @as(i32, @intCast(overlay_scale)), overlay_y + 5 * @as(i32, @intCast(overlay_scale)), text_color, overlay_scale);

        overlay_y += line_height;

        // Draw render time with label
        const render_time = self.getSectionTime("Render");
        text_module.drawStringScaled(framebuffer, "REN", overlay_x + 5 * @as(i32, @intCast(overlay_scale)), overlay_y + 5 * @as(i32, @intCast(overlay_scale)), text_color, overlay_scale);
        text_module.drawFloatScaled(framebuffer, @as(f32, @floatCast(render_time)), 1, overlay_x + 40 * @as(i32, @intCast(overlay_scale)), overlay_y + 5 * @as(i32, @intCast(overlay_scale)), text_color, overlay_scale);
    }
};