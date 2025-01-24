#ifndef RAYLIB_WRAPPER_H
#define RAYLIB_WRAPPER_H

#include <raylib.h>
#include <stdbool.h>

void init_window(int width, int height, const char *title);
void close_window(void);
void begin_drawing(void);
void end_drawing(void);
void clear_background(Color color);
void draw_rectangle(int posX, int posY, int width, int height, Color color);
int get_screen_width(void);
int get_screen_height(void);
void set_target_fps(int fps);
bool window_should_close(void);
bool is_window_ready(void);
void toggle_fullscreen(void);
void set_window_state(unsigned int flags);
Color get_black(void);
Color get_white(void);
unsigned int get_flag_fullscreen_mode(void);
void draw_text(const char *text, int posX, int posY, int fontSize, Color color);
Font load_font(const char *fileName);
void draw_text_ex(Font font, const char *text, Vector2 position, float fontSize, float spacing, Color tint);
Vector2 measure_text_ex(Font font, const char *text, float fontSize, float spacing);

#endif // RAYLIB_WRAPPER_H