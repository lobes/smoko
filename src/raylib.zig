const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raylib_wrapper.h");
});

pub const Color = c.Color;
pub const Font = c.Font;
pub const Vector2 = c.Vector2;

pub fn initWindow(width: i32, height: i32, title: [*c]const u8) void {
    c.init_window(width, height, title);
}

pub fn closeWindow() void {
    c.close_window();
}

pub fn beginDrawing() void {
    c.begin_drawing();
}

pub fn endDrawing() void {
    c.end_drawing();
}

pub fn clearBackground(color: Color) void {
    c.clear_background(color);
}

pub fn drawRectangle(posX: i32, posY: i32, width: i32, height: i32, color: Color) void {
    c.draw_rectangle(posX, posY, width, height, color);
}

pub fn getScreenWidth() i32 {
    return c.get_screen_width();
}

pub fn getScreenHeight() i32 {
    return c.get_screen_height();
}

pub fn setTargetFPS(fps: i32) void {
    c.set_target_fps(fps);
}

pub fn windowShouldClose() bool {
    return c.window_should_close();
}

pub fn isWindowReady() bool {
    return c.is_window_ready();
}

pub fn toggleFullscreen() void {
    c.toggle_fullscreen();
}

pub fn setWindowState(flags: u32) void {
    c.set_window_state(flags);
}

pub fn drawText(text: [*c]const u8, posX: i32, posY: i32, fontSize: i32, color: Color) void {
    c.draw_text(text, posX, posY, fontSize, color);
}

pub fn loadFont(fileName: [*c]const u8) Font {
    return c.load_font(fileName);
}

pub fn drawTextEx(font: Font, text: [*c]const u8, position: Vector2, fontSize: f32, spacing: f32, tint: Color) void {
    c.draw_text_ex(font, text, position, fontSize, spacing, tint);
}

pub fn measureTextEx(font: Font, text: [*c]const u8, fontSize: f32, spacing: f32) Vector2 {
    return c.measure_text_ex(font, text, fontSize, spacing);
}

pub const BLACK = c.BLACK;
pub const WHITE = c.WHITE;
pub const FLAG_FULLSCREEN_MODE = 0x00000002; // Hardcoded value from raylib.h
