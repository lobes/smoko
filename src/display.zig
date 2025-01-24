const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib.zig");

const TextAnimation = struct {
    position: rl.Vector2,
    velocity: rl.Vector2,
    text: [*c]const u8,
    font: rl.Font,
    font_size: f32,
    spacing: f32,
    bounds: rl.Vector2,
    screen_width: i32,
    screen_height: i32,

    pub fn init(text: [*c]const u8, font: rl.Font, screen_width: i32, screen_height: i32) TextAnimation {
        const font_size: f32 = 120;
        const spacing: f32 = 4;
        const bounds = rl.measureTextEx(font, text, font_size, spacing);

        return TextAnimation{
            .position = .{ .x = 100, .y = 100 },
            .velocity = .{ .x = 5, .y = 3 },
            .text = text,
            .font = font,
            .font_size = font_size,
            .spacing = spacing,
            .bounds = bounds,
            .screen_width = screen_width,
            .screen_height = screen_height,
        };
    }

    pub fn update(self: *TextAnimation) void {
        // Update position
        self.position.x += self.velocity.x;
        self.position.y += self.velocity.y;

        // Bounce off walls
        if (self.position.x < 0 or self.position.x + self.bounds.x > @as(f32, @floatFromInt(self.screen_width))) {
            self.velocity.x = -self.velocity.x;
            if (self.position.x < 0) self.position.x = 0;
            if (self.position.x + self.bounds.x > @as(f32, @floatFromInt(self.screen_width))) {
                self.position.x = @as(f32, @floatFromInt(self.screen_width)) - self.bounds.x;
            }
        }
        if (self.position.y < 0 or self.position.y + self.bounds.y > @as(f32, @floatFromInt(self.screen_height))) {
            self.velocity.y = -self.velocity.y;
            if (self.position.y < 0) self.position.y = 0;
            if (self.position.y + self.bounds.y > @as(f32, @floatFromInt(self.screen_height))) {
                self.position.y = @as(f32, @floatFromInt(self.screen_height)) - self.bounds.y;
            }
        }
    }

    pub fn draw(self: *const TextAnimation) void {
        rl.drawTextEx(self.font, self.text, self.position, self.font_size, self.spacing, rl.WHITE);
    }
};

pub const DisplayManager = struct {
    allocator: Allocator,
    windows_initialized: bool = false,
    font: rl.Font = undefined,
    animation: ?TextAnimation = null,

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
            self.animation = TextAnimation.init("ON SMOKO", self.font, rl.getScreenWidth(), rl.getScreenHeight());
        }

        // Draw black rectangle until window is closed
        while (!rl.windowShouldClose()) {
            const screen_width = rl.getScreenWidth();
            const screen_height = rl.getScreenHeight();
            rl.beginDrawing();
            rl.clearBackground(rl.BLACK);
            rl.drawRectangle(0, 0, screen_width, screen_height, rl.BLACK);

            // Update and draw bouncing text
            if (self.animation) |*anim| {
                anim.update();
                anim.draw();
            }

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
