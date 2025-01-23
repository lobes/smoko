const std = @import("std");

pub const Config = struct {
    // Default values for countdown timers
    config_dir: []const u8 = ".config/smoko",
    pre_blank_countdown_secs: u32 = 3,
    post_blank_countdown_secs: u32 = 3,

    pub fn loadOrCreate() !Config {
        const config_path = try getConfigPath();

        // Try to load existing config
        if (std.fs.path.dirname(config_path)) |dir| {
            try std.fs.cwd().makePath(dir);
        }

        const file = std.fs.openFileAbsolute(config_path, .{ .mode = .read_only }) catch |err| switch (err) {
            error.FileNotFound => {
                // Create default config
                var config = Config{};
                try config.save();
                return config;
            },
            else => return err,
        };
        defer file.close();

        var buf: [1024]u8 = undefined;
        const bytes_read = try file.readAll(&buf);

        var config = Config{};
        var lines = std.mem.split(u8, buf[0..bytes_read], "\n");
        while (lines.next()) |line| {
            var kv = std.mem.split(u8, line, "=");
            const key = std.mem.trim(u8, kv.first(), " ");
            const value = if (kv.next()) |v| std.mem.trim(u8, v, " ") else continue;

            inline for (std.meta.fields(Config)) |field| {
                if (std.mem.eql(u8, key, field.name)) {
                    switch (field.type) {
                        []const u8 => @field(config, field.name) = value,
                        u32 => @field(config, field.name) = try std.fmt.parseInt(u32, value, 10),
                        else => {},
                    }
                }
            }
        }

        return config;
    }

    pub fn save(self: Config) !void {
        const config_path = try getConfigPath();

        if (std.fs.path.dirname(config_path)) |dir| {
            try std.fs.cwd().makePath(dir);
        }

        const file = try std.fs.createFileAbsolute(config_path, .{});
        defer file.close();

        var writer = file.writer();

        // Iterate over all fields in Config
        inline for (std.meta.fields(Config)) |field| {
            const value = @field(self, field.name);
            switch (field.type) {
                []const u8 => try writer.print("{s}={s}\n", .{ field.name, value }),
                u32 => try writer.print("{s}={d}\n", .{ field.name, value }),
                else => {},
            }
        }
    }
};

fn getConfigPath() ![]const u8 {
    const home = try std.process.getEnvVarOwned(std.heap.page_allocator, "HOME");
    defer std.heap.page_allocator.free(home);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Config directory: {s}/.config\n", .{home});
    return try std.fs.path.join(std.heap.page_allocator, &[_][]const u8{ home, ".config", "smoko", "config.txt" });
}
