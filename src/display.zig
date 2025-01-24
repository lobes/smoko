const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib.zig");

pub const DisplayManager = struct {
    allocator: Allocator,
    windows_initialized: bool = false,
    font: rl.Font = undefined,

    pub fn init(allocator: Allocator, max_displays: u32) !DisplayManager {
        _ = max_displays;
        return DisplayManager{
            .allocator = allocator,
            .windows_initialized = false,
        };
    }

    pub fn deinit(self: *DisplayManager) void {
        if (self.windows_initialized) {
            rl.closeWindow();
        }
    }

    pub fn captureAll(self: *DisplayManager, writer: anytype) !void {
        try writer.print("Initializing display...\n", .{});

        // Initialize raylib window
        if (!self.windows_initialized) {
            rl.initWindow(800, 600, "Smoko");
            rl.setWindowState(rl.FLAG_FULLSCREEN_MODE);
            rl.setTargetFPS(60);
            self.windows_initialized = true;
            self.font = rl.loadFont("/Users/lobes/Library/Fonts/ComicCodeLigatures-Regular.otf");
        }

        // Draw black rectangle until window is closed
        while (!rl.windowShouldClose()) {
            const screen_width = rl.getScreenWidth();
            const screen_height = rl.getScreenHeight();
            rl.beginDrawing();
            rl.clearBackground(rl.BLACK);
            rl.drawRectangle(0, 0, screen_width, screen_height, rl.BLACK);

            // Draw text
            const text = "ON SMOKO";
            const font_size: f32 = 120;
            const spacing: f32 = 4;
            const text_size = rl.measureTextEx(self.font, text, font_size, spacing);
            const text_pos = rl.Vector2{
                .x = @as(f32, @floatFromInt(screen_width)) / 2 - text_size.x / 2,
                .y = @as(f32, @floatFromInt(screen_height)) / 2 - text_size.y / 2,
            };
            rl.drawTextEx(self.font, text, text_pos, font_size, spacing, rl.WHITE);

            rl.endDrawing();
        }

        // Clean up when window is closed
        self.releaseAll();
    }

    pub fn releaseAll(self: *DisplayManager) void {
        if (self.windows_initialized) {
            rl.closeWindow();
            self.windows_initialized = false;
        }
    }

    pub fn showAllCursors(self: *DisplayManager) void {
        _ = self;
        // No need to do anything since raylib handles cursor visibility
    }
};
