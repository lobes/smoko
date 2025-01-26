const std = @import("std");

/// Common options for renderer initialization
pub const Options = struct {
    width: u32,
    height: u32,
    vsync: bool = true,
};

/// The health status of a renderer
pub const Health = enum(c_int) {
    healthy = 0,
    unhealthy = 1,
};

/// Color representation using RGBA values
pub const Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub const white = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
    pub const black = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
};

/// The type of rendering operation to perform
pub const RenderOp = enum {
    clear,
    wall, // Draw a wall segment
    sprite, // Draw a sprite
    texture, // Draw a textured surface
};

/// Common rendering commands that all renderer implementations must support
pub const RenderCommand = struct {
    op: RenderOp,
    x: f32,
    y: f32,
    z: f32, // Height for walls
    texture_id: ?u32, // Optional texture reference
    color: Color,
};

/// Software renderer implementation
pub const Renderer = struct {
    width: u32,
    height: u32,
    buffer: []u32, // Pixel buffer
    z_buffer: []f32, // Depth buffer for proper ordering
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, options: Options) !Renderer {
        const buffer = try allocator.alloc(u32, options.width * options.height);
        const z_buffer = try allocator.alloc(f32, options.width * options.height);

        return Renderer{
            .width = options.width,
            .height = options.height,
            .buffer = buffer,
            .z_buffer = z_buffer,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.allocator.free(self.buffer);
        self.allocator.free(self.z_buffer);
    }

    pub fn clear(self: *Renderer, color: Color) !void {
        const pixel = @as(u32, color.r) << 24 |
            @as(u32, color.g) << 16 |
            @as(u32, color.b) << 8 |
            @as(u32, color.a);

        for (0..self.buffer.len) |i| {
            self.buffer[i] = pixel;
            self.z_buffer[i] = std.math.inf(f32);
        }
    }

    pub fn drawLine(self: *Renderer, x1: i32, y1: i32, x2: i32, y2: i32, color: Color) !void {
        const pixel = @as(u32, color.r) << 24 |
            @as(u32, color.g) << 16 |
            @as(u32, color.b) << 8 |
            @as(u32, color.a);

        var x = x1;
        var y = y1;
        const dx = @as(i32, @intCast(@abs(x2 - x1)));
        const dy = @as(i32, @intCast(@abs(y2 - y1)));
        const sx = if (x1 < x2) @as(i32, 1) else @as(i32, -1);
        const sy = if (y1 < y2) @as(i32, 1) else @as(i32, -1);
        var err = dx - dy;

        while (true) {
            if (x >= 0 and x < @as(i32, @intCast(self.width)) and
                y >= 0 and y < @as(i32, @intCast(self.height)))
            {
                self.buffer[@as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x))] = pixel;
            }
            if (x == x2 and y == y2) break;
            const e2 = 2 * err;
            if (e2 > -dy) {
                err -= dy;
                x += sx;
            }
            if (e2 < dx) {
                err += dx;
                y += sy;
            }
        }
    }

    // TODO: Add methods for:
    // - Drawing walls
    // - Drawing sprites
    // - Texture mapping
    // - BSP traversal
};
