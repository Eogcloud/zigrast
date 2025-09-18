// platform/settings.zig
const std = @import("std");

pub const LaunchSettings = struct {
    window: WindowSettings,
    rendering: RenderingSettings,
    performance: PerformanceSettings,

    const WindowSettings = struct {
        width: u32,
        height: u32,
        title: []const u8,
        resizable: bool,
        vsync: bool,
    };

    const RenderingSettings = struct {
        clear_color: [3]u8, // RGB
        fov_degrees: f32,
        near_plane: f32,
        far_plane: f32,
    };

    const PerformanceSettings = struct {
        show_overlay: bool,
        target_fps: u32,
        enable_frame_cap: bool,
    };

    pub fn loadFromFile(allocator: std.mem.Allocator, file_path: []const u8) !LaunchSettings {
        // Try to read the file
        const file_content = std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("Settings file '{s}' not found. Creating default settings.\n", .{file_path});
                const default_settings = getDefaultSettings();
                try saveDefaultSettings(file_path);
                return default_settings;
            },
            else => {
                std.debug.print("Error reading settings file '{s}': {s}\n", .{ file_path, @errorName(err) });
                return err;
            },
        };
        defer allocator.free(file_content);

        // Parse JSON
        var parsed = std.json.parseFromSlice(std.json.Value, allocator, file_content, .{}) catch |err| {
            std.debug.print("Error parsing JSON in '{s}': {s}\n", .{ file_path, @errorName(err) });
            std.debug.print("Using default settings instead.\n", .{});
            return getDefaultSettings();
        };
        defer parsed.deinit();

        const root = parsed.value;

        // Extract settings with validation
        const settings = LaunchSettings{
            .window = WindowSettings{
                .width = validateU32(getJsonU32(root, "window", "width") orelse 800, 320, 3840, "window.width"),
                .height = validateU32(getJsonU32(root, "window", "height") orelse 600, 240, 2160, "window.height"),
                .title = allocator.dupe(u8, getJsonString(root, "window", "title") orelse "ZigRast - Software Renderer") catch "ZigRast - Software Renderer",
                .resizable = getJsonBool(root, "window", "resizable") orelse true,
                .vsync = getJsonBool(root, "window", "vsync") orelse false,
            },
            .rendering = RenderingSettings{
                .clear_color = validateColor(getJsonColorArray(root, "rendering", "clear_color") orelse [3]u8{ 0, 17, 34 }),
                .fov_degrees = validateF32(getJsonF32(root, "rendering", "fov_degrees") orelse 60.0, 30.0, 120.0, "rendering.fov_degrees"),
                .near_plane = validateF32(getJsonF32(root, "rendering", "near_plane") orelse 0.1, 0.01, 10.0, "rendering.near_plane"),
                .far_plane = validateF32(getJsonF32(root, "rendering", "far_plane") orelse 100.0, 10.0, 1000.0, "rendering.far_plane"),
            },
            .performance = PerformanceSettings{
                .show_overlay = getJsonBool(root, "performance", "show_overlay") orelse true,
                .target_fps = validateU32(getJsonU32(root, "performance", "target_fps") orelse 60, 30, 300, "performance.target_fps"),
                .enable_frame_cap = getJsonBool(root, "performance", "enable_frame_cap") orelse true,
            },
        };

        return settings;
    }

    fn getDefaultSettings() LaunchSettings {
        return LaunchSettings{
            .window = WindowSettings{
                .width = 800,
                .height = 600,
                .title = "ZigRast - Software Renderer",
                .resizable = true,
                .vsync = false,
            },
            .rendering = RenderingSettings{
                .clear_color = [3]u8{ 0, 17, 34 }, // Dark blue
                .fov_degrees = 60.0,
                .near_plane = 0.1,
                .far_plane = 100.0,
            },
            .performance = PerformanceSettings{
                .show_overlay = true,
                .target_fps = 60,
                .enable_frame_cap = true,
            },
        };
    }

    fn saveDefaultSettings(file_path: []const u8) !void {
        const default_json =
            \\{
            \\  "window": {
            \\    "width": 800,
            \\    "height": 600,
            \\    "title": "ZigRast - Software Renderer",
            \\    "resizable": true,
            \\    "vsync": false
            \\  },
            \\  "rendering": {
            \\    "clear_color": [0, 17, 34],
            \\    "fov_degrees": 60.0,
            \\    "near_plane": 0.1,
            \\    "far_plane": 100.0
            \\  },
            \\  "performance": {
            \\    "show_overlay": true,
            \\    "target_fps": 60,
            \\    "enable_frame_cap": true
            \\  }
            \\}
        ;

        std.fs.cwd().writeFile(.{ .sub_path = file_path, .data = default_json }) catch |err| {
            std.debug.print("Warning: Could not create default settings file: {s}\n", .{@errorName(err)});
        };
    }

    pub fn getClearColor(self: LaunchSettings) u32 {
        const r = @as(u32, self.rendering.clear_color[0]);
        const g = @as(u32, self.rendering.clear_color[1]);
        const b = @as(u32, self.rendering.clear_color[2]);
        return (r << 24) | (g << 16) | (b << 8) | 0xFF;
    }

    pub fn getFrameDelay(self: LaunchSettings) u32 {
        // If VSync is enabled, let the driver pace; no timer cap.
        if (self.window.vsync) return 0;
        if (!self.performance.enable_frame_cap) return 0;
        return 1000 / self.performance.target_fps;
    }
};

// Helper functions for JSON parsing
fn getJsonU32(root: std.json.Value, section: []const u8, key: []const u8) ?u32 {
    const section_obj = root.object.get(section) orelse return null;
    const value = section_obj.object.get(key) orelse return null;
    return switch (value) {
        .integer => @as(u32, @intCast(value.integer)),
        else => null,
    };
}

fn getJsonF32(root: std.json.Value, section: []const u8, key: []const u8) ?f32 {
    const section_obj = root.object.get(section) orelse return null;
    const value = section_obj.object.get(key) orelse return null;
    return switch (value) {
        .float => @as(f32, @floatCast(value.float)),
        .integer => @as(f32, @floatFromInt(value.integer)),
        else => null,
    };
}

fn getJsonString(root: std.json.Value, section: []const u8, key: []const u8) ?[]const u8 {
    const section_obj = root.object.get(section) orelse return null;
    const value = section_obj.object.get(key) orelse return null;
    return switch (value) {
        .string => value.string,
        else => null,
    };
}

fn getJsonBool(root: std.json.Value, section: []const u8, key: []const u8) ?bool {
    const section_obj = root.object.get(section) orelse return null;
    const value = section_obj.object.get(key) orelse return null;
    return switch (value) {
        .bool => value.bool,
        else => null,
    };
}

fn getJsonColorArray(root: std.json.Value, section: []const u8, key: []const u8) ?[3]u8 {
    const section_obj = root.object.get(section) orelse return null;
    const value = section_obj.object.get(key) orelse return null;
    const array = switch (value) {
        .array => value.array,
        else => return null,
    };

    if (array.items.len != 3) return null;

    var result: [3]u8 = undefined;
    for (0..3) |i| {
        result[i] = switch (array.items[i]) {
            .integer => @as(u8, @intCast(std.math.clamp(array.items[i].integer, 0, 255))),
            else => return null,
        };
    }
    return result;
}

// Validation functions
fn validateU32(value: u32, min_val: u32, max_val: u32, field_name: []const u8) u32 {
    if (value < min_val or value > max_val) {
        std.debug.print("Warning: {s} value {d} is out of range [{d}-{d}], clamping.\n", .{ field_name, value, min_val, max_val });
        return std.math.clamp(value, min_val, max_val);
    }
    return value;
}

fn validateF32(value: f32, min_val: f32, max_val: f32, field_name: []const u8) f32 {
    if (value < min_val or value > max_val) {
        std.debug.print("Warning: {s} value {d:.2} is out of range [{d:.2}-{d:.2}], clamping.\n", .{ field_name, value, min_val, max_val });
        return std.math.clamp(value, min_val, max_val);
    }
    return value;
}

fn validateColor(color: [3]u8) [3]u8 {
    return color; // RGB values are already constrained to 0-255 by u8 type
}
