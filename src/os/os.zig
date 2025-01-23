const builtin = @import("builtin");

pub const os = switch (builtin.os.tag) {
    .macos => @import("macos.zig"),
    else => @compileError("Unsupported operating system"),
};
