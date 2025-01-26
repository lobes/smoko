//! Doom engine implementation for Smoko
//! This provides the core functionality for running Doom levels

const std = @import("std");
const renderer = @import("renderer");
const wad = @import("./wad.zig");
const map = @import("./map.zig");

/// Basic vector type for 3D positions and directions
pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }
};

/// Player state including position, angle, etc.
pub const Player = struct {
    position: Vec3,
    angle: f32, // In radians
    height: f32,
    velocity: Vec3,

    pub fn init() Player {
        return .{
            .position = Vec3.init(0, 0, 0),
            .angle = 0,
            .height = 41, // Doom's player height
            .velocity = Vec3.init(0, 0, 0),
        };
    }

    pub fn moveForward(self: *Player, amount: f32) void {
        self.position.x += @cos(self.angle) * amount;
        self.position.y += @sin(self.angle) * amount;
    }

    pub fn rotate(self: *Player, angle_delta: f32) void {
        self.angle += angle_delta;
    }
};

/// Main game state
pub const Game = struct {
    renderer: *renderer.Renderer,
    player: Player,
    wad_file: wad.Wad,
    palette: [256][3]u8,
    current_map: map.Map,

    pub fn init(allocator: std.mem.Allocator, r: *renderer.Renderer) !Game {
        // Load the WAD file
        var wad_file = try wad.Wad.init(allocator, "src/wads/doom.wad");
        errdefer wad_file.deinit();

        // Load the palette
        const playpal = try wad_file.getLump("PLAYPAL");
        var palette: [256][3]u8 = undefined;
        for (0..256) |i| {
            palette[i][0] = playpal[i * 3];
            palette[i][1] = playpal[i * 3 + 1];
            palette[i][2] = playpal[i * 3 + 2];
        }

        // Load E1M1
        var current_map = try map.Map.loadFromWad(allocator, &wad_file, "E1M1");
        errdefer current_map.deinit();

        // Find player start position
        var player = Player.init();
        for (current_map.things) |thing| {
            if (thing.type == 1) { // Player 1 start
                player.position.x = @as(f32, @floatFromInt(thing.x));
                player.position.y = @as(f32, @floatFromInt(thing.y));
                player.angle = @as(f32, @floatFromInt(thing.angle)) * std.math.pi / 180.0;
                break;
            }
        }

        return Game{
            .renderer = r,
            .player = player,
            .wad_file = wad_file,
            .palette = palette,
            .current_map = current_map,
        };
    }

    pub fn deinit(self: *Game) void {
        self.current_map.deinit();
        self.wad_file.deinit();
    }

    pub fn update(self: *Game, dt: f32) void {
        // Apply movement based on velocity
        self.player.position.x += self.player.velocity.x * dt;
        self.player.position.y += self.player.velocity.y * dt;
        self.player.position.z += self.player.velocity.z * dt;

        // Apply friction to slow down movement
        const friction = 0.9;
        self.player.velocity.x *= friction;
        self.player.velocity.y *= friction;
        self.player.velocity.z *= friction;

        // Clamp player height
        const min_height = 41.0; // Standard Doom player height
        if (self.player.position.z < min_height) {
            self.player.position.z = min_height;
            self.player.velocity.z = 0;
        }
    }

    pub fn render(self: *Game) !void {
        // Clear screen
        try self.renderer.clear(.{ .r = 0, .g = 0, .b = 0, .a = 255 });

        // Project and render walls
        for (self.current_map.linedefs) |linedef| {
            const v1 = self.current_map.vertices[linedef.start_vertex];
            const v2 = self.current_map.vertices[linedef.end_vertex];

            // Transform vertices relative to player
            const rel_start = Vec3{
                .x = @as(f32, @floatFromInt(v1.x)) - self.player.position.x,
                .y = @as(f32, @floatFromInt(v1.y)) - self.player.position.y,
                .z = 0,
            };
            const rel_end = Vec3{
                .x = @as(f32, @floatFromInt(v2.x)) - self.player.position.x,
                .y = @as(f32, @floatFromInt(v2.y)) - self.player.position.y,
                .z = 0,
            };

            // Rotate vertices around player
            const cos_angle = @cos(-self.player.angle);
            const sin_angle = @sin(-self.player.angle);

            const rot_start = Vec3{
                .x = rel_start.x * cos_angle - rel_start.y * sin_angle,
                .y = rel_start.x * sin_angle + rel_start.y * cos_angle,
                .z = rel_start.z,
            };
            const rot_end = Vec3{
                .x = rel_end.x * cos_angle - rel_end.y * sin_angle,
                .y = rel_end.x * sin_angle + rel_end.y * cos_angle,
                .z = rel_end.z,
            };

            // Skip walls behind player
            if (rot_start.y < 1 and rot_end.y < 1) continue;

            // Project to screen space
            const fov = 90.0;
            const half_width = @as(f32, @floatFromInt(self.renderer.width)) / 2.0;
            const half_height = @as(f32, @floatFromInt(self.renderer.height)) / 2.0;
            const proj_scale = half_width / @tan(fov * std.math.pi / 360.0);

            const x1 = half_width + rot_start.x * proj_scale / rot_start.y;
            const x2 = half_width + rot_end.x * proj_scale / rot_end.y;

            // Draw wall line
            try self.renderer.drawLine(
                @intFromFloat(x1),
                @intFromFloat(half_height - 20),
                @intFromFloat(x2),
                @intFromFloat(half_height + 20),
                .{ .r = 255, .g = 255, .b = 255, .a = 255 },
            );
        }
    }
};

test "doom - basic game init" {
    const allocator = std.testing.allocator;

    var r = try renderer.Renderer.init(allocator, .{
        .width = 320,
        .height = 200,
        .vsync = true,
    });
    defer r.deinit();

    var game = try Game.init(allocator, &r);
    defer game.deinit();

    try game.render();
}
