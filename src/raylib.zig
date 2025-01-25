const c = @cImport({
    @cInclude("raylib.h");
});

pub const Color = c.Color;
pub const Font = c.Font;
pub const Vector2 = c.Vector2;

pub fn initWindow(width: i32, height: i32, title: [*c]const u8) void {
    c.InitWindow(width, height, title);
}

pub fn closeWindow() void {
    c.CloseWindow();
}

pub fn beginDrawing() void {
    c.BeginDrawing();
}

pub fn endDrawing() void {
    c.EndDrawing();
}

pub fn clearBackground(color: Color) void {
    c.ClearBackground(color);
}

pub fn drawRectangle(posX: i32, posY: i32, width: i32, height: i32, color: Color) void {
    c.DrawRectangle(posX, posY, width, height, color);
}

pub fn getScreenWidth() i32 {
    return c.GetScreenWidth();
}

pub fn getScreenHeight() i32 {
    return c.GetScreenHeight();
}

pub fn setTargetFPS(fps: i32) void {
    c.SetTargetFPS(fps);
}

pub fn windowShouldClose() bool {
    return c.WindowShouldClose();
}

pub fn isWindowReady() bool {
    return c.IsWindowReady();
}

pub fn toggleFullscreen() void {
    c.ToggleFullscreen();
}

pub fn setWindowState(flags: u32) void {
    c.SetWindowState(flags);
}

pub fn drawText(text: [*c]const u8, posX: i32, posY: i32, fontSize: i32, color: Color) void {
    c.DrawText(text, posX, posY, fontSize, color);
}

pub fn loadFont(fileName: [*c]const u8) Font {
    return c.LoadFont(fileName);
}

pub fn drawTextEx(font: Font, text: [*c]const u8, position: Vector2, fontSize: f32, spacing: f32, tint: Color) void {
    c.DrawTextEx(font, text, position, fontSize, spacing, tint);
}

pub fn measureTextEx(font: Font, text: [*c]const u8, fontSize: f32, spacing: f32) Vector2 {
    return c.MeasureTextEx(font, text, fontSize, spacing);
}

pub fn getMonitorCount() i32 {
    return c.GetMonitorCount();
}

pub fn getMonitorPosition(monitor: i32) Vector2 {
    return c.GetMonitorPosition(monitor);
}

pub fn getMonitorWidth(monitor: i32) i32 {
    return c.GetMonitorWidth(monitor);
}

pub fn getMonitorHeight(monitor: i32) i32 {
    return c.GetMonitorHeight(monitor);
}

pub fn setWindowPosition(x: i32, y: i32) void {
    c.SetWindowPosition(x, y);
}

pub const BLACK = c.BLACK;
pub const WHITE = c.WHITE;
pub const FLAG_FULLSCREEN_MODE = c.FLAG_FULLSCREEN_MODE;

pub fn initWindowOnMonitor(width: i32, height: i32, title: [*c]const u8, monitor: i32) void {
    c.InitWindowOnMonitor(width, height, title, monitor);
}
