const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const process = std.process;
const fmt = std.fmt;
const heap = std.heap;
const meta = std.meta;

const DEFAULT_CONFIG_PATH = "~/.config/smoko/config.txt";

pub const Config = struct {
    pub const Options = enum {
        buffer_before, // seconds of input lock before display is locked
        smoko_length, // minutes of smoko
        lock_length, // minutes of lock

        pub fn fromString(str: []const u8) ?Options {
            inline for (comptime std.meta.tags(Options)) |tag| {
                if (mem.eql(u8, str, @tagName(tag))) {
                    return tag;
                }
            }
            return null;
        }
    };

    buffer_before: u32 = 3, // seconds of input lock before display is locked
    smoko_length: u32 = 3, // minutes of smoko
    lock_length: u32 = 1, // minutes of lock

    pub fn loadOrCreate() !Config {
        var cfg = Config{};

        // Try to load existing config
        const config_path = try getConfigPath();
        defer heap.page_allocator.free(config_path);

        // Create config directory if it doesn't exist
        if (fs.path.dirname(config_path)) |dir| {
            try fs.cwd().makePath(dir);
        }

        // Try to open existing config file
        const file = fs.openFileAbsolute(config_path, .{ .mode = .read_only }) catch |err| switch (err) {
            error.FileNotFound => {
                // Save default config to disk
                try saveDefaults(config_path);
                return Config{};
            },
            else => return err,
        };
        defer file.close();

        // Read and parse existing config
        var buf: [1024]u8 = undefined;
        const bytes_read = try file.readAll(&buf);

        var lines = mem.split(u8, buf[0..bytes_read], "\n");
        while (lines.next()) |line| {
            var kv = mem.split(u8, line, "=");
            const key = mem.trim(u8, kv.first(), " ");
            const value = if (kv.next()) |v| mem.trim(u8, v, " ") else continue;

            if (Options.fromString(key)) |option| {
                switch (option) {
                    .buffer_before => cfg.buffer_before = try fmt.parseInt(u32, value, 10),
                    .smoko_length => cfg.smoko_length = try fmt.parseInt(u32, value, 10),
                    .lock_length => cfg.lock_length = try fmt.parseInt(u32, value, 10),
                }
            }
        }

        return cfg;
    }

    fn saveDefaults(config_path: []const u8) !void {
        const file = try fs.createFileAbsolute(config_path, .{});
        defer file.close();

        var writer = file.writer();

        // Write default values
        try writer.print("{s}={d}\n", .{ @tagName(Options.buffer_before), 3 });
        try writer.print("{s}={d}\n", .{ @tagName(Options.smoko_length), 3 });
        try writer.print("{s}={d}\n", .{ @tagName(Options.lock_length), 1 });
    }

    pub fn save(self: Config) !void {
        const config_path = try getConfigPath();
        defer heap.page_allocator.free(config_path);

        if (fs.path.dirname(config_path)) |dir| {
            try fs.cwd().makePath(dir);
        }

        const file = try fs.createFileAbsolute(config_path, .{});
        defer file.close();

        var writer = file.writer();

        // Write all options
        inline for (comptime std.meta.tags(Options)) |option| {
            const value = switch (option) {
                .buffer_before => self.buffer_before,
                .smoko_length => self.smoko_length,
                .lock_length => self.lock_length,
            };
            try writer.print("{s}={d}\n", .{ @tagName(option), value });
        }
    }
};

pub fn getConfigPath() ![]const u8 {
    const home = try process.getEnvVarOwned(heap.page_allocator, "HOME");
    defer heap.page_allocator.free(home);

    return try fs.path.join(heap.page_allocator, &[_][]const u8{ home, ".config", "smoko", "config.txt" });
}
