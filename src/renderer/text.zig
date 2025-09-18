// renderer/text.zig
const std = @import("std");
const Framebuffer = @import("framebuffer.zig").Framebuffer;

// 6x8 bitmap font (subset)
// Each row uses the low 6 bits.
pub const FONT_WIDTH: i32 = 6;
pub const FONT_HEIGHT: i32 = 8;
const CHAR_OFFSET: u8 = 32; // first glyph is ' '
const CHAR_SPACING: i32 = 1; // horizontal spacing between glyphs

// NOTE: Table covers 32..90 inclusive (space..'Z'). Punctuation we don't draw is left empty.
const FONT_DATA = [_][@intCast(FONT_HEIGHT)]u8{
    // 32 ' '
    .{ 0b000000, 0b000000, 0b000000, 0b000000, 0b000000, 0b000000, 0b000000, 0b000000 },
    // 33-47 (punctuation - minimal)
    .{ 0b001100, 0b001100, 0b001100, 0b001100, 0b001100, 0b000000, 0b001100, 0b000000 }, // !
    .{ 0, 0, 0, 0, 0, 0, 0, 0 }, // "
    .{ 0, 0, 0, 0, 0, 0, 0, 0 }, // #
    .{ 0, 0, 0, 0, 0, 0, 0, 0 }, // $
    .{ 0, 0, 0, 0, 0, 0, 0, 0 }, // %
    .{ 0, 0, 0, 0, 0, 0, 0, 0 }, // &
    .{ 0, 0, 0, 0, 0, 0, 0, 0 }, // '
    .{ 0, 0, 0, 0, 0, 0, 0, 0 }, // (
    .{ 0, 0, 0, 0, 0, 0, 0, 0 }, // )
    .{ 0, 0, 0, 0, 0, 0, 0, 0 }, // *
    .{ 0, 0, 0, 0, 0, 0, 0, 0 }, // +
    .{ 0b000000, 0b000000, 0b000000, 0b000000, 0b000000, 0b001100, 0b001100, 0b011000 }, // , (44)
    .{ 0b000000, 0b000000, 0b000000, 0b111111, 0b000000, 0b000000, 0b000000, 0b000000 }, // - (45)
    .{ 0b000000, 0b000000, 0b000000, 0b000000, 0b000000, 0b001100, 0b001100, 0b000000 }, // . (46)
    .{ 0, 0, 0, 0, 0, 0, 0, 0 }, // /
    // 48..57 digits
    .{ 0b000000, 0b011100, 0b100010, 0b100110, 0b101010, 0b110010, 0b100010, 0b011100 }, // 0
    .{ 0b000000, 0b001000, 0b011000, 0b001000, 0b001000, 0b001000, 0b001000, 0b111110 }, // 1
    .{ 0b000000, 0b011100, 0b100010, 0b000010, 0b001100, 0b110000, 0b100000, 0b111110 }, // 2
    .{ 0b000000, 0b011100, 0b100010, 0b000010, 0b001100, 0b000010, 0b100010, 0b011100 }, // 3
    .{ 0b000000, 0b000100, 0b001100, 0b010100, 0b100100, 0b111110, 0b000100, 0b000100 }, // 4
    .{ 0b000000, 0b111110, 0b100000, 0b111100, 0b000010, 0b000010, 0b100010, 0b011100 }, // 5
    .{ 0b000000, 0b001110, 0b010000, 0b100000, 0b111100, 0b100010, 0b100010, 0b011100 }, // 6
    .{ 0b000000, 0b111110, 0b000010, 0b000100, 0b001000, 0b010000, 0b010000, 0b010000 }, // 7
    .{ 0b000000, 0b011100, 0b100010, 0b100010, 0b011100, 0b100010, 0b100010, 0b011100 }, // 8
    .{ 0b000000, 0b011100, 0b100010, 0b100010, 0b011110, 0b000010, 0b000100, 0b111000 }, // 9
    .{ 0b000000, 0b000000, 0b011000, 0b011000, 0b000000, 0b011000, 0b011000, 0b000000 }, // :
    // 59..64 (empty)
    .{ 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 0, 0, 0, 0, 0, 0, 0, 0 },
    // 65..90 A..Z
    .{ 0b000000, 0b011100, 0b100010, 0b100010, 0b111110, 0b100010, 0b100010, 0b100010 }, // A
    .{ 0b000000, 0b111100, 0b100010, 0b100010, 0b111100, 0b100010, 0b100010, 0b111100 }, // B
    .{ 0b000000, 0b011100, 0b100010, 0b100000, 0b100000, 0b100000, 0b100010, 0b011100 }, // C
    .{ 0b000000, 0b111100, 0b100010, 0b100010, 0b100010, 0b100010, 0b100010, 0b111100 }, // D
    .{ 0b000000, 0b111110, 0b100000, 0b100000, 0b111100, 0b100000, 0b100000, 0b111110 }, // E
    .{ 0b000000, 0b111110, 0b100000, 0b100000, 0b111100, 0b100000, 0b100000, 0b100000 }, // F
    .{ 0b000000, 0b011100, 0b100010, 0b100000, 0b101110, 0b100010, 0b100010, 0b011100 }, // G
    .{ 0b000000, 0b100010, 0b100010, 0b100010, 0b111110, 0b100010, 0b100010, 0b100010 }, // H
    .{ 0b000000, 0b111110, 0b001000, 0b001000, 0b001000, 0b001000, 0b001000, 0b111110 }, // I
    .{ 0b000000, 0b111110, 0b000010, 0b000010, 0b000010, 0b000010, 0b100010, 0b011100 }, // J
    .{ 0b000000, 0b100010, 0b100100, 0b101000, 0b110000, 0b101000, 0b100100, 0b100010 }, // K
    .{ 0b000000, 0b100000, 0b100000, 0b100000, 0b100000, 0b100000, 0b100000, 0b111110 }, // L
    .{ 0b000000, 0b100010, 0b110110, 0b101010, 0b100010, 0b100010, 0b100010, 0b100010 }, // M
    .{ 0b000000, 0b100010, 0b110010, 0b101010, 0b100110, 0b100010, 0b100010, 0b100010 }, // N
    .{ 0b000000, 0b011100, 0b100010, 0b100010, 0b100010, 0b100010, 0b100010, 0b011100 }, // O
    .{ 0b000000, 0b111100, 0b100010, 0b100010, 0b111100, 0b100000, 0b100000, 0b100000 }, // P
    .{ 0b000000, 0b011100, 0b100010, 0b100010, 0b100010, 0b101010, 0b100100, 0b011110 }, // Q
    .{ 0b000000, 0b111100, 0b100010, 0b100010, 0b111100, 0b101000, 0b100100, 0b100010 }, // R
    .{ 0b000000, 0b011100, 0b100010, 0b100000, 0b011100, 0b000010, 0b100010, 0b011100 }, // S
    .{ 0b000000, 0b111110, 0b001000, 0b001000, 0b001000, 0b001000, 0b001000, 0b001000 }, // T
    .{ 0b000000, 0b100010, 0b100010, 0b100010, 0b100010, 0b100010, 0b100010, 0b011100 }, // U
    .{ 0b000000, 0b100010, 0b100010, 0b100010, 0b100010, 0b100010, 0b010100, 0b001000 }, // V
    .{ 0b000000, 0b100010, 0b100010, 0b100010, 0b100010, 0b101010, 0b110110, 0b100010 }, // W
    .{ 0b000000, 0b100010, 0b100010, 0b010100, 0b001000, 0b010100, 0b100010, 0b100010 }, // X
    .{ 0b000000, 0b100010, 0b100010, 0b010100, 0b001000, 0b001000, 0b001000, 0b001000 }, // Y
    .{ 0b000000, 0b111110, 0b000010, 0b000100, 0b001000, 0b010000, 0b100000, 0b111110 }, // Z
};

inline fn mapChar(ch_in: u8) u8 {
    // Map lowercase to uppercase so we can render with the A..Z glyphs.
    return switch (ch_in) {
        'a'...'z' => ch_in - 32, // ASCII delta
        else => ch_in,
    };
}

inline fn setPixelClipped(fb: *Framebuffer, x: i32, y: i32, color: u32) void {
    if (x < 0 or y < 0) return;
    if (x >= @as(i32, @intCast(fb.width))) return;
    if (y >= @as(i32, @intCast(fb.height))) return;
    fb.setPixel(x, y, color);
}

pub fn drawChar(framebuffer: *Framebuffer, ch_in: u8, x: i32, y: i32, color: u32) void {
    drawCharScaled(framebuffer, ch_in, x, y, color, 1);
}

pub fn drawCharScaled(framebuffer: *Framebuffer, ch_in: u8, x: i32, y: i32, color: u32, scale: u32) void {
    if (scale == 0) return;

    const ch = mapChar(ch_in);
    if (ch < 32 or ch > 90) return; // Supported range: space..'Z'

    const idx: usize = @intCast(ch - CHAR_OFFSET);
    if (idx >= FONT_DATA.len) return;
    const glyph = FONT_DATA[idx];

    const s: i32 = @intCast(scale);

    var row: i32 = 0;
    while (row < FONT_HEIGHT) : (row += 1) {
        const bits: u8 = glyph[@intCast(row)];
        var col: i32 = 0;
        while (col < FONT_WIDTH) : (col += 1) {
            const bit_index: u3 = @intCast(FONT_WIDTH - 1 - col);
            if (((bits >> bit_index) & 1) == 1) {
                // Scale each lit pixel to an s×s block
                var dy: i32 = 0;
                while (dy < s) : (dy += 1) {
                    var dx: i32 = 0;
                    while (dx < s) : (dx += 1) {
                        setPixelClipped(framebuffer, x + col * s + dx, y + row * s + dy, color);
                    }
                }
            }
        }
    }
}

pub fn drawString(framebuffer: *Framebuffer, text: []const u8, start_x: i32, start_y: i32, color: u32) void {
    drawStringScaled(framebuffer, text, start_x, start_y, color, 1);
}

pub fn drawStringScaled(framebuffer: *Framebuffer, text: []const u8, start_x: i32, start_y: i32, color: u32, scale: u32) void {
    if (scale == 0) return;

    var x = start_x;
    var y = start_y;
    const adv = (FONT_WIDTH + CHAR_SPACING) * @as(i32, @intCast(scale));
    const line = (FONT_HEIGHT + 1) * @as(i32, @intCast(scale));

    for (text) |raw_ch| {
        switch (raw_ch) {
            '\n' => {
                x = start_x;
                y += line;
            },
            '\r' => {
                x = start_x;
            },
            '\t' => {
                x += adv * 4;
            },
            else => {
                drawCharScaled(framebuffer, raw_ch, x, y, color, scale);
                x += adv;
            },
        }
    }
}

pub fn drawNumber(framebuffer: *Framebuffer, number: anytype, x: i32, y: i32, color: u32) void {
    drawNumberScaled(framebuffer, number, x, y, color, 1);
}

pub fn drawNumberScaled(framebuffer: *Framebuffer, number: anytype, x: i32, y: i32, color: u32, scale: u32) void {
    var buf: [32]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, "{d}", .{number}) catch return;
    drawStringScaled(framebuffer, s, x, y, color, scale);
}

pub fn drawFloat(framebuffer: *Framebuffer, number: f32, decimals: u8, x: i32, y: i32, color: u32) void {
    drawFloatScaled(framebuffer, number, decimals, x, y, color, 1);
}

pub fn drawFloatScaled(framebuffer: *Framebuffer, number: f32, decimals: u8, x: i32, y: i32, color: u32, scale: u32) void {
    var buf: [32]u8 = undefined;
    const s = switch (decimals) {
        0 => std.fmt.bufPrint(&buf, "{d:.0}", .{number}) catch return,
        1 => std.fmt.bufPrint(&buf, "{d:.1}", .{number}) catch return,
        2 => std.fmt.bufPrint(&buf, "{d:.2}", .{number}) catch return,
        else => std.fmt.bufPrint(&buf, "{d:.1}", .{number}) catch return,
    };
    drawStringScaled(framebuffer, s, x, y, color, scale);
}
