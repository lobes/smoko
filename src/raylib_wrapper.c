#include <raylib.h>

void init_window(int width, int height, const char *title)
{
  InitWindow(width, height, title);
}

void close_window(void)
{
  CloseWindow();
}

void begin_drawing(void)
{
  BeginDrawing();
}

void end_drawing(void)
{
  EndDrawing();
}

void clear_background(Color color)
{
  ClearBackground(color);
}

void draw_rectangle(int posX, int posY, int width, int height, Color color)
{
  DrawRectangle(posX, posY, width, height, color);
}

int get_screen_width(void)
{
  return GetScreenWidth();
}

int get_screen_height(void)
{
  return GetScreenHeight();
}

void set_target_fps(int fps)
{
  SetTargetFPS(fps);
}

bool window_should_close(void)
{
  return WindowShouldClose();
}

bool is_window_ready(void)
{
  return IsWindowReady();
}

void toggle_fullscreen(void)
{
  ToggleFullscreen();
}

void set_window_state(unsigned int flags)
{
  SetWindowState(flags);
}

Color get_black(void)
{
  return BLACK;
}

Color get_white(void)
{
  return WHITE;
}

unsigned int get_flag_fullscreen_mode(void)
{
  return FLAG_FULLSCREEN_MODE;
}

void draw_text(const char *text, int posX, int posY, int fontSize, Color color)
{
  DrawText(text, posX, posY, fontSize, color);
}

Font load_font(const char *fileName)
{
  return LoadFont(fileName);
}

void draw_text_ex(Font font, const char *text, Vector2 position, float fontSize, float spacing, Color tint)
{
  DrawTextEx(font, text, position, fontSize, spacing, tint);
}

Vector2 measure_text_ex(Font font, const char *text, float fontSize, float spacing)
{
  return MeasureTextEx(font, text, fontSize, spacing);
}