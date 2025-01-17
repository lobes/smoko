const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const macos = @import("macos.zig");
const builtin = @import("builtin");

const usage =
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
    \\  clear              "No more smokos."
    \\                         - when it's the end of the day and you've just gotta get it done
    \\  s                  Show status of scheduled smokos
    \\  pass               "I gotta skip this smoko" - when duty calls
    \\  help               Show this help message
;

pub fn main() !void {
    // Check if we can access binary `pmset` orelse

    // Check if we're running on macOS
    if (builtin.os.tag != .macos) {
        debug.err("Error: This program only works on macOS\n", .{});
        std.process.exit(1);
    }

    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);
    const stdout = std.io.getStdOut().writer();

    // Sub-Commands
    {
        if (args.len == 0) {
            try stdout.writeAll(usage);
            debug.print("args.len was {s}", .{args.len});
            return std.process.cleanExit();
        }

        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (mem.eql(u8, "-h", arg) or mem.eql(u8, "help", arg)) {
                try stdout.writeAll(usage);
                debug.print("arg was {s}", .{args});
                return std.process.cleanExit();
            } else {
                fatal("unrecognised arg: {s}", .{arg});
            }
        }
    }

    debug.print("Made it to the end of main.");

    return 0;
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}

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

fn printHelp() void {}
