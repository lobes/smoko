const std = @import("std");
const macos = @import("macos.zig");
const builtin = @import("builtin");

//TODO find a way to lock screen in macOS

fn printHelp() void {
    std.debug.print(
        \\Usage: smoko [options] [minutes]
        \\
        \\Options:
        \\  -h, --help             Show this help message
        \\  -l [n], --list=[n]     List [n] coming smokos, sorted by time until smoko (default: all)
        \\  -n, --next             List next coming smoko (equivalent to -list=1)
        \\  -s, --secure           Lock the screen instead of sleeping displays
        \\  -c, --countdown        Leave a countdown in the terminal instead of scheduling
        \\ 
        \\Arguments:
        \\  minutes            Time to wait for smoko (default: 0)
        \\
        \\Examples:
        \\  smoko              Sleep displays immediately
        \\  smoko 47           Schedule a smoko to sleep displays after 47 minutes
        \\  smoko -c 10        Display a countdown for 10 minutes, refreshing every minute
        \\  smoko -n           List next coming smoko
        \\  smoko -l           List all coming smokos
        \\  smoko -l 5         List 5 coming smokos
    , .{});
    std.process.exit(0);
}

/// Get the program name from a full path
fn getProgramName(path: []const u8) []const u8 {
    const sep = std.fs.path.sep_str;
    const last_sep = std.mem.lastIndexOf(u8, path, sep) orelse return path;
    return path[last_sep + 1 ..];
}

pub fn main() !void {
    // Check if we're running on macOS
    if (builtin.os.tag != .macos) {
        std.debug.print("Error: This program only works on macOS\n", .{});
        std.process.exit(1);
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Default configuration
    var should_lock = false;
    var minutes: u32 = 0;
    var show_countdown = false;

    // Check environment variable for default lock behavior
    const default_lock = std.process.getEnvVarOwned(allocator, "SMOKO_DEFAULT_LOCK") catch null;
    defer if (default_lock) |dl| allocator.free(dl);
    if (default_lock) |dl| {
        should_lock = std.mem.eql(u8, dl, "1");
    }

    // Parse arguments
    var arg_idx: usize = 1;
    while (arg_idx < args.len) : (arg_idx += 1) {
        const arg = args[arg_idx];
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printHelp();
            return;
        } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--secure")) {
            should_lock = true;
        } else if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--countdown")) {
            show_countdown = true;
        } else {
            // Try to parse as minutes
            minutes = std.fmt.parseInt(u32, arg, 10) catch {
                std.debug.print("Error: '{s}' is not a valid number of minutes\n", .{arg});
                std.process.exit(1);
            };
        }
    }

    // Print initial message and start countdown if requested
    if (show_countdown) {
        const action = if (should_lock) "Lock session" else "Sleep displays";
        var mins_left = minutes;
        while (mins_left > 0) : (mins_left -= 1) {
            std.debug.print("\r{s} in {} minute{s}...", .{
                action, mins_left, if (mins_left == 1) "" else "s",
            });
            std.time.sleep(std.time.ns_per_s * 60);
        }
        std.debug.print("\n", .{});
    }

    try if (should_lock)
        macos.lockSession(minutes)
    else
        macos.setDisplaysToSleep(minutes);
}

test "simple test" {
    // TODO: Replace this test with more relevant ones
    // For now, we just ensure everything compiles
    _ = macos;
}
