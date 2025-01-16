const std = @import("std");
const macos = @import("macos.zig");
const builtin = @import("builtin");

//TODO find a way to lock screen in macOS

// ## Sub-Commands

// Smoko is a bucket of sub commands:
// `smoko now`
// `smoko in 7`
// `smoko at 3`
// `smoko s`
// `smoko pass`
// `smoko moveto in 11`
// `smoko moveto at noon`
// `smoko wipe`
// `smoko help`

fn now() void {
    std.debug.print("smoko now!\n", .{});
}

fn printHelp() void {
    std.debug.print(
        \\Usage: smoko <command> [args]
        \\
        \\Commands:
        \\  now                "Down tools. Smoko."
        \\                         - whatever you say, boss
        \\  in <minutes>       "Going for smoko in 5."
        \\                         - when you're asked to do a shitty job and need a break before you start
        \\  at <time>          "We're having smoko at 10."
        \\                         - what you tell the lads so they stop asking
        \\  when               "How long till smoko?"
        \\                         - when you don't know if you're gonna make it
        \\  next in <minutes>  "Next smoko in 5."
        \\                         - gotta be flexable
        \\  next at <time>     "Pushing smoko to 11."
        \\                         - shit happens
        \\  wipe               "No more smokos today." - when it's the end of the day and the rest is just one long smoko anyway
        \\  s                  Show status of scheduled smokos
        \\  pass               "I gotta skip this smoko" - when duty calls
        \\  help               Show this help message
        \\
        \\Examples: coming soon
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

    now();

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
