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

    pub fn init(text: [*c]const u8, font: rl.Font) TextAnimation {
        const font_size: f32 = 120;
        const spacing: f32 = 4;
        const bounds = rl.measureTextEx(font, text, font_size, spacing);

        // Start in the middle of the screen
        const screen_width = @as(f32, @floatFromInt(rl.getScreenWidth()));
        const screen_height = @as(f32, @floatFromInt(rl.getScreenHeight()));
        const start_x = (screen_width - bounds.x) / 2;
        const start_y = (screen_height - bounds.y) / 2;

        return TextAnimation{
            .position = .{ .x = start_x, .y = start_y },
            .velocity = .{ .x = 5, .y = 3 },
            .text = text,
            .font = font,
            .font_size = font_size,
            .spacing = spacing,
            .bounds = bounds,
        };
    }

    pub fn update(self: *TextAnimation) void {
        self.updatePosition();
        self.handleBoundaryCollisions();
    }

    fn updatePosition(self: *TextAnimation) void {
        self.position.x += self.velocity.x;
        self.position.y += self.velocity.y;
    }

    fn handleBoundaryCollisions(self: *TextAnimation) void {
        const screen = Screen{
            .width = @as(f32, @floatFromInt(rl.getScreenWidth())),
            .height = @as(f32, @floatFromInt(rl.getScreenHeight())),
        };

        // Handle horizontal collisions
        const right_edge = self.position.x + self.bounds.x;
        if (self.position.x < 0 or right_edge > screen.width) {
            self.velocity.x = -self.velocity.x;
            if (self.position.x < 0) self.position.x = 0;
            if (right_edge > screen.width) self.position.x = screen.width - self.bounds.x;
        }

        // Handle vertical collisions
        const bottom_edge = self.position.y + self.bounds.y;
        if (self.position.y < 0 or bottom_edge > screen.height) {
            self.velocity.y = -self.velocity.y;
            if (self.position.y < 0) self.position.y = 0;
            if (bottom_edge > screen.height) self.position.y = screen.height - self.bounds.y;
        }
    }

    pub fn draw(self: *const TextAnimation) void {
        rl.drawTextEx(self.font, self.text, self.position, self.font_size, self.spacing, rl.WHITE);
    }
};

const Screen = struct {
    width: f32,
    height: f32,
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
            // Initialize at a large resolution
            rl.initWindow(1920, 1080, "Smoko");
            rl.setWindowState(rl.FLAG_FULLSCREEN_MODE);
            rl.setTargetFPS(60);
            self.windows_initialized = true;
            self.font = rl.loadFont("/Users/lobes/Library/Fonts/ComicCodeLigatures-Regular.otf");
            self.animation = TextAnimation.init("ON SMOKO", self.font);
        }

        // Main render loop
        while (!rl.windowShouldClose()) {
            self.drawFrame();
        }

        // Clean up when window is closed
        self.releaseAll();
    }

    fn drawFrame(self: *DisplayManager) void {
        const screen_width = rl.getScreenWidth();
        const screen_height = rl.getScreenHeight();

        rl.beginDrawing();
        defer rl.endDrawing();

        // Clear screen
        rl.clearBackground(rl.BLACK);
        rl.drawRectangle(0, 0, screen_width, screen_height, rl.BLACK);

        // Update and draw animation
        if (self.animation) |*anim| {
            anim.update();
            anim.draw();
        }
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
