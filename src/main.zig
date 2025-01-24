const std = @import("std");
const process = std.process;
const heap = std.heap;
const ArenaAllocator = std.heap.ArenaAllocator;
const Writer = std.fs.File.Writer;
const io = std.io;
const mem = std.mem;
const fmt = std.fmt;
const time = std.time;
const builtin = @import("builtin");
const config = @import("config.zig");
const Config = config.Config;
const d = @import("display.zig");
const DisplayManager = d.DisplayManager;

const OS = struct {
    const c = if (builtin.os.tag == .macos)
        @cImport({
            @cInclude("ApplicationServices/ApplicationServices.h");
            @cInclude("CoreGraphics/CoreGraphics.h");
        })
    else
        struct {};
};

// Global state
var cfg: Config = undefined;
var stdout: Writer = undefined;
var arena: ArenaAllocator = undefined;
var input: Input = undefined;
var display: DisplayManager = undefined;

const HELP_TEXT =
    \\Usage: smoko <time>
    \\
    \\Examples:
    \\  smoko
    \\
    \\     -- Immediately blank all displays
    \\                  "Down tools. Smoko."
    \\
    \\  smoko 5
    \\
    \\     -- Display countdown in mins. Blank all displays
    \\        after countdown
    \\
    \\                 "Going on smoko in 5."
    \\
    \\
;

/// Smoko - A command-line tool for enforcing screen breaks
///
/// This program helps enforce screen breaks by:
/// 1. Optionally counting down for a specified number of minutes
/// 2. Blocking all keyboard and mouse input
/// 3. Blanking all connected displays
/// 4. Waiting for a configured duration
/// 5. Restoring displays and input
///
/// Usage:
///   smoko       - Start smoko immediately
///   smoko config - Print config and fullpath
///   smoko edit   - Open config in $EDITOR
///   smoko <N>   - Start smoko in N minutes
///   smoko -h | help - Show this help
///
/// Default configuration is stored in ~/.config/smoko/config.txt (edit with `smoko edit`).
pub fn main() !void {
    // 1. init globals
    stdout = io.getStdOut().writer();
    arena = ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();

    cfg = try Config.loadOrCreate();

    input = try Input.init();
    defer input.deinit();

    display = try DisplayManager.init(arena.allocator(), 16);
    defer display.deinit();

    // 2. check OS support
    if (builtin.os.tag != .macos) {
        try stdout.print("Error: {s} is not supported\n", .{@tagName(builtin.os.tag)});
        return error.UnsupportedOS;
    }

    // 3. parse args
    const args = try parseArgs();

    // 4. run action based on args
    try runAction(args);
}

const Action = union(enum) {
    help,
    immediate,
    config,
    edit,
    countdown: u32,
};

fn parseArgs() !Action {
    var args = process.args();
    _ = args.skip(); // program name

    const arg = args.next() orelse return .immediate;

    if (mem.eql(u8, arg, "help") or mem.eql(u8, arg, "-h")) return .help;
    if (mem.eql(u8, arg, "config")) return .config;
    if (mem.eql(u8, arg, "edit")) return .edit;
    return Action{ .countdown = try fmt.parseInt(u32, arg, 10) };
}

fn runAction(action: Action) !void {
    switch (action) {
        .help => try showHelp(),
        .immediate => try startSmoko(),
        .config => try showConfig(),
        .edit => try editConfig(),
        .countdown => |mins| try startCountdown(mins),
    }
}

fn showHelp() !void {
    try stdout.writeAll(HELP_TEXT);
}

fn startSmoko() !void {
    try stdout.print("\rTime for smoko.                 \n", .{});

    // try input.block();
    try stdout.print("Input blocked. Blanking displays in {d} seconds...\n", .{cfg.buffer_before});
    const buffer_ns: u64 = @as(u64, cfg.buffer_before) * time.ns_per_s;
    time.sleep(buffer_ns);

    // This will block until the window is closed
    try display.captureAll(&stdout);
    try stdout.print("Break complete.\n", .{});
}

fn showConfig() !void {
    const config_path = try config.getConfigPath();
    defer heap.page_allocator.free(config_path);

    try stdout.print("config_path: {s}\n\n", .{config_path});
    try stdout.print("buffer_before: {d}\n", .{cfg.buffer_before});
    try stdout.print("smoko_length: {d}\n", .{cfg.smoko_length});
    try stdout.print("lock_length: {d}\n", .{cfg.lock_length});
}

fn editConfig() !void {
    try stdout.print("Editing config file...\n", .{});

    const config_path = try config.getConfigPath();
    defer heap.page_allocator.free(config_path);

    // Try to get $EDITOR from environment, or use default
    var editor_buf: []const u8 = undefined;
    var should_free_editor = false;
    editor_buf = process.getEnvVarOwned(heap.page_allocator, "EDITOR") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => "open",
        else => return err,
    };
    if (!mem.eql(u8, editor_buf, "open")) {
        should_free_editor = true;
    }
    defer if (should_free_editor) heap.page_allocator.free(editor_buf);

    var cmd = process.Child.init(&[_][]const u8{ editor_buf, config_path }, heap.page_allocator);
    try cmd.spawn();
    _ = try cmd.wait();
}

fn startCountdown(minutes: u32) !void {
    var mins_remaining: u32 = minutes;
    while (mins_remaining > 0) : (mins_remaining -= 1) {
        try stdout.print("\rSmoko in {d} minutes.", .{mins_remaining});
        time.sleep(time.ns_per_min);
    }

    try startSmoko();
}

const Input = struct {
    tap: if (builtin.os.tag == .macos) ?OS.c.CFMachPortRef else void,

    fn init() !Input {
        return Input{ .tap = null };
    }

    fn deinit(self: *Input) void {
        if (builtin.os.tag == .macos) {
            if (self.tap) |t| {
                OS.c.CGEventTapEnable(t, false);
            }
        }
    }

    fn block(self: *Input) !void {
        if (builtin.os.tag == .macos) {
            const event_mask = OS.c.CGEventMaskBit(OS.c.kCGEventKeyDown) |
                OS.c.CGEventMaskBit(OS.c.kCGEventKeyUp) |
                OS.c.CGEventMaskBit(OS.c.kCGEventMouseMoved) |
                OS.c.CGEventMaskBit(OS.c.kCGEventLeftMouseDown) |
                OS.c.CGEventMaskBit(OS.c.kCGEventLeftMouseUp) |
                OS.c.CGEventMaskBit(OS.c.kCGEventRightMouseDown) |
                OS.c.CGEventMaskBit(OS.c.kCGEventRightMouseUp) |
                OS.c.CGEventMaskBit(OS.c.kCGEventScrollWheel) |
                OS.c.CGEventMaskBit(OS.c.kCGEventFlagsChanged);

            const tap = OS.c.CGEventTapCreate(
                OS.c.kCGSessionEventTap,
                OS.c.kCGHeadInsertEventTap,
                OS.c.kCGEventTapOptionDefault,
                event_mask,
                eventCallback,
                null,
            );

            if (tap == null) return error.FailedToCreateEventTap;

            const run_loop_source = OS.c.CFMachPortCreateRunLoopSource(
                OS.c.kCFAllocatorDefault,
                tap,
                0,
            );

            if (run_loop_source == null) {
                if (tap) |t| OS.c.CFRelease(t);
                return error.FailedToCreateRunLoopSource;
            }
            defer if (run_loop_source) |s| OS.c.CFRelease(s);

            OS.c.CFRunLoopAddSource(
                OS.c.CFRunLoopGetCurrent(),
                run_loop_source,
                OS.c.kCFRunLoopCommonModes,
            );

            OS.c.CGEventTapEnable(tap, true);
            self.tap = tap;
        }
    }

    fn restore(self: *Input) void {
        if (builtin.os.tag == .macos) {
            if (self.tap) |t| {
                OS.c.CGEventTapEnable(t, false);
                OS.c.CFRelease(t);
                self.tap = null;
            }
        }
    }
};

fn eventCallback(
    proxy: OS.c.CGEventTapProxy,
    event_type: OS.c.CGEventType,
    event: OS.c.CGEventRef,
    user_info: ?*anyopaque,
) callconv(.C) OS.c.CGEventRef {
    _ = proxy;
    _ = event_type;
    _ = event;
    _ = user_info;
    return null;
}
