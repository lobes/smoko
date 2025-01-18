const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const macos = @import("macos.zig");
const builtin = @import("builtin");

const HELP_TEXT =
    \\Usage: smoko <action> [args]
    \\
    \\Action:
    \\  now                -- Immediately set all displays to sleep
    \\                      "Down tools. Smoko."
    \\  add 5m             -- Set all displays to sleep in 5 minutes
    \\                      "Going on smoko in 5."
    \\  add 10am           -- Set all displays to sleep at 10:00AM
    \\                      "It's smoko at 10."
    \\  next               -- Print countdown to smoko
    \\                      "How long till smoko?"
    \\  list               -- Print all smoko countdowns
    \\                      "How many smokos do we get?"
    \\  edit 1m            -- Reset countdown to smoko
    \\                      "One minute till smoko."
    \\  skip               -- Delete next scheduled smoko
    \\                      "Nah, I'm good."
    \\  clear              -- Delete all scheduled smokos
    \\                      "No more smokos."
    \\  help               -- Show this help message
    \\
;

pub fn main() !void {
    // Get everything ready

    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);
    const stdout = std.io.getStdOut().writer();

    {
        if (args.len == 1) {
            try stdout.writeAll(HELP_TEXT);
            return std.process.cleanExit();
        }

        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            debug.print("{s}\n", .{arg});
            if (mem.eql(u8, "-h", arg) or mem.eql(u8, "help", arg)) {
                try stdout.writeAll(HELP_TEXT);
                return std.process.cleanExit();
            } else if (mem.eql(u8, "add", arg)) {
                try setupLaunchd();
            } else {
                fatal("unrecognised arg: {s}", .{arg});
            }
        }
    }
}

pub fn setupLaunchd() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const env_vars = std.process.EnvMap.init(arena);

    const plist_path = try std.fs.path.join(
        std.heap.page_allocator,
        &[_][]const u8{ env_vars.get("HOME") orelse return error.NoHome, "Library", "LaunchAgents", "com.example.pmsetscheduler.plist" },
    );
    defer std.heap.page_allocator.free(plist_path);

    // Create the plist file
    const file = try std.fs.createFileAbsolute(plist_path, .{});
    defer file.close();

    // Write the plist content
    try file.writeAll(
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        \\<plist version="1.0">
        \\<dict>
        \\    <key>Label</key>
        \\    <string>com.example.pmsetscheduler</string>
        \\    <key>ProgramArguments</key>
        \\    <array>
        \\        <string>/usr/sbin/pmset</string>
        \\        <string>displaysleepnow</string>
        \\    </array>
        \\    <key>StartCalendarInterval</key>
        \\    <dict>
        \\        <key>Hour</key>
        \\        <integer>0</integer>
        \\        <key>Minute</key>
        \\        <integer>0</integer>
        \\    </dict>
        \\    <key>RunAtLoad</key>
        \\    <false/>
        \\    <key>StandardErrorPath</key>
        \\    <string>/tmp/pmset.err</string>
        \\    <key>StandardOutPath</key>
        \\    <string>/tmp/pmset.out</string>
        \\</dict>
        \\</plist>
    );

    // Load the launchd job
    var child = std.process.Child.init(&[_][]const u8{ "launchctl", "load", plist_path }, std.heap.page_allocator);
    _ = try child.spawnAndWait();
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}

fn setDisplaysToSleep(minutes: u32) !void {
    // Convert minutes to nanoseconds and sleep
    // Use u64 to avoid integer overflow
    const ns_per_minute: u64 = @as(u64, std.time.ns_per_s) * 60;
    const total_ns: u64 = ns_per_minute * minutes;
    std.time.sleep(total_ns);

    std.debug.print("Time's up! Putting display to sleep...\n", .{});

    const result = try std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{ "pmset", "displaysleepnow" },
    });

    if (result.term.Exited != 0) {
        std.debug.print("Failed to put display to sleep\n", .{});
        return error.SetDisplaysToSleepFailed;
    }
}

// Smoko is a bucket of actions:
// smoko now
// smoko add 3m
// smoko add 1030
// smoko add 2pm
// smoko list
// smoko skip
// smoko edit 3m
// smoko edit 1030
// smoko edit 2pm
// smoko clear
// smoko help
