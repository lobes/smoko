# DOOM Port Checklist

## Math
- [x] Vector operations (via `@Vector` builtin)
- [x] Matrix operations (via `std.math` and `@Vector`)
- [x] Trigonometry functions (via `std.math`)
  ```zig
  const std = @import("std");
  const pi = std.math.pi;
  const sin = std.math.sin;
  const cos = std.math.cos;
  ```

## Memory Management
- [x] Dynamic arrays (via `std.ArrayList`)
- [x] Memory allocation (via `std.heap.GeneralPurposeAllocator`)
- [x] Buffer management (via `std.io.BufferedReader`)
  ```zig
  const std = @import("std");
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  const allocator = gpa.allocator();
  ```

## File Handling
- [x] File I/O (via `std.fs.File`)
- [x] Binary reading (via `std.io.Reader`)
- [ ] WAD file format parsing
  - [ ] Directory entries
  - [ ] Lump reading
  - [ ] Data decompression

## Graphics
- [ ] OpenGL context setup
- [ ] Shader management
- [ ] Texture loading
  - [ ] Wall textures
  - [ ] Flat textures
  - [ ] Sprite textures
- [ ] Palette handling
- [ ] Rendering pipeline
  - [ ] BSP traversal
  - [ ] Wall rendering
  - [ ] Floor/ceiling rendering
  - [ ] Sprite rendering

## Game Logic
- [ ] Map loading
  - [ ] Vertices
  - [ ] Linedefs
  - [ ] Sectors
  - [ ] Things
- [ ] Player movement
- [ ] Collision detection
- [ ] Game state management
- [ ] Animation system

## Input
- [ ] Keyboard handling
- [ ] Mouse input
- [ ] Input mapping

## Engine Core
- [ ] Game loop
- [ ] Timing system
- [ ] Event system
- [ ] Resource management

## Audio
- [ ] Sound system
- [ ] Music playback
- [ ] Sound effects
- [ ] Audio mixing

## Networking (if needed)
- [ ] Network protocol
- [ ] Client/server architecture
- [ ] Game state synchronization

## Tools
- [ ] Map viewer
- [ ] WAD inspector
- [ ] Debug visualization

## Original Source Files to Port

From `/Users/lobes/things/doom/src`:
- [ ] wall_texture.c
- [ ] flat_texture.c
- [ ] gl_helpers.c
- [ ] input.c
- [ ] main.c
- [ ] map.c
- [ ] matrix.c
- [ ] mesh.c
- [ ] palette.c
- [ ] renderer.c
- [ ] vector.c
- [ ] wad.c
- [ ] camera.c

From `/Users/lobes/things/doom/src/engine`:
- [ ] meshgen.c
- [ ] util.c
- [ ] anim.c
- [ ] engine.c 