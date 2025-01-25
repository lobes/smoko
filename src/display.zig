const std = @import("std");
const renderer = @import("renderer");

pub const Display = struct {
    renderer: renderer.RendererInterface,
    options: renderer.Options,

    pub fn init(options: renderer.Options) !Display {
        var self = Display{
            .renderer = undefined,
            .options = options,
        };

        const health = self.renderer.init(options);
        if (health == .unhealthy) {
            return error.RendererInitFailed;
        }

        return self;
    }

    pub fn deinit(self: *Display) void {
        self.renderer.deinit();
    }

    pub fn drawRect(self: *Display, x: f32, y: f32, width: f32, height: f32, color: renderer.Color) !void {
        const cmd = renderer.RenderCommand{
            .op = .rect,
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .color = color,
        };

        const health = self.renderer.submit(cmd);
        if (health == .unhealthy) {
            return error.RenderCommandFailed;
        }
    }

    pub fn drawText(self: *Display, x: f32, y: f32, text: []const u8, color: renderer.Color) !void {
        const cmd = renderer.RenderCommand{
            .op = .text,
            .x = x,
            .y = y,
            .width = 0, // Text width will be determined by the renderer
            .height = 0,
            .color = color,
            .text = text,
        };

        const health = self.renderer.submit(cmd);
        if (health == .unhealthy) {
            return error.RenderCommandFailed;
        }
    }

    pub fn clear(self: *Display, color: renderer.Color) !void {
        const cmd = renderer.RenderCommand{
            .op = .clear,
            .x = 0,
            .y = 0,
            .width = 0,
            .height = 0,
            .color = color,
        };

        const health = self.renderer.submit(cmd);
        if (health == .unhealthy) {
            return error.RenderCommandFailed;
        }
    }

    pub fn present(self: *Display) !void {
        const health = self.renderer.present();
        if (health == .unhealthy) {
            return error.PresentFailed;
        }
    }
};

// Example usage:
test "basic rendering" {
    var display = try Display.init(.{
        // Add required options here
    });
    defer display.deinit();

    // Clear screen to black
    try display.clear(.{ .r = 0, .g = 0, .b = 0, .a = 255 });

    // Draw a red rectangle
    try display.drawRect(
        10, 10, 100, 50,
        .{ .r = 255, .g = 0, .b = 0, .a = 255 }
    );

    // Draw some text
    try display.drawText(
        20, 20,
        "Hello Smoko!",
        .{ .r = 255, .g = 255, .b = 255, .a = 255 }
    );

    try display.present();
}