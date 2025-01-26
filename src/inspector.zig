const std = @import("std");
const wad = @import("wad.zig");

pub fn main() !void {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <wad_file>\n", .{args[0]});
        return;
    }

    // Load WAD file
    var wadFile = try wad.Wad.load(args[1], allocator);
    defer wadFile.deinit();

    try listLumps(&wadFile);
}

pub fn listLumps(wadFile: *const wad.Wad) !void {
    const stdout = std.io.getStdOut().writer();

    // Print WAD header info
    try stdout.print("WAD File Info:\n", .{});
    try stdout.print("  Type: {s}\n", .{@tagName(wadFile.header.wad_type)});
    try stdout.print("  Lump Count: {d}\n", .{wadFile.header.num_lumps});
    try stdout.print("\nLumps:\n", .{});
    try stdout.print("  {:>4} | {:<8} | {:>8} | {:>8} | {s}\n", .{ "Idx", "Name", "Size", "Offset", "Type" });
    try stdout.writeAll("  ");
    try stdout.writeByteNTimes('-', 50);
    try stdout.writeAll("\n");

    // Print each lump's info
    for (wadFile.lumps, 0..) |lump, i| {
        const name = lump.getName();
        const lumpType = classifyLump(name);
        try stdout.print("  {:>4} | {s:<8} | {:>8} | {:>8} | {s}\n", .{
            i,
            name,
            lump.size,
            lump.offset,
            lumpType,
        });
    }
}

fn classifyLump(name: []const u8) []const u8 {
    if (std.mem.eql(u8, name, "PLAYPAL")) return "Palette";
    if (std.mem.eql(u8, name, "COLORMAP")) return "Colormap";
    if (std.mem.eql(u8, name, "ENDOOM")) return "End Screen";
    if (std.mem.startsWith(u8, name, "E") and std.mem.endsWith(u8, name, "M")) return "Map Marker";
    if (std.mem.eql(u8, name, "TEXTURE1") or std.mem.eql(u8, name, "TEXTURE2")) return "Texture List";
    if (std.mem.eql(u8, name, "PNAMES")) return "Patch Names";
    if (std.mem.startsWith(u8, name, "S_START") or std.mem.startsWith(u8, name, "SS_START")) return "Sprite Marker";
    if (std.mem.startsWith(u8, name, "S_END") or std.mem.startsWith(u8, name, "SS_END")) return "Sprite Marker";
    if (std.mem.startsWith(u8, name, "F_START")) return "Flat Marker";
    if (std.mem.startsWith(u8, name, "F_END")) return "Flat Marker";
    if (std.mem.eql(u8, name, "VERTEXES")) return "Map Data (Vertices)";
    if (std.mem.eql(u8, name, "LINEDEFS")) return "Map Data (Lines)";
    if (std.mem.eql(u8, name, "SIDEDEFS")) return "Map Data (Sides)";
    if (std.mem.eql(u8, name, "NODES")) return "Map Data (BSP)";
    if (std.mem.eql(u8, name, "SECTORS")) return "Map Data (Sectors)";
    if (std.mem.eql(u8, name, "REJECT")) return "Map Data (Reject)";
    if (std.mem.eql(u8, name, "BLOCKMAP")) return "Map Data (Blockmap)";
    if (std.mem.eql(u8, name, "THINGS")) return "Map Data (Things)";
    if (std.mem.eql(u8, name, "SEGS")) return "Map Data (Segments)";
    if (std.mem.eql(u8, name, "SSECTORS")) return "Map Data (Subsectors)";
    return "Data";
}

fn inspectLump(wad_file: *wad.Wad, name: []const u8) !void {
    const lump = wad_file.findLump(name) orelse {
        std.debug.print("Lump '{s}' not found\n", .{name});
        return;
    };

    std.debug.print("\nLump: {s}\n", .{name});
    std.debug.print("Size: {d} bytes\n", .{lump.size});
    std.debug.print("Offset: {d}\n", .{lump.offset});
    std.debug.print("Type: {s}\n", .{classifyLump(name)});

    // Read lump data
    const data = wad_file.readLump(lump);

    // Handle different lump types
    if (std.mem.eql(u8, name, "PLAYPAL")) {
        const palette = try wad_file.readPalette();
        std.debug.print("\nPalette data: {d} colors\n", .{palette.colors.len});
        // Print first few colors as RGB values
        std.debug.print("\nFirst 16 colors (RGB):\n", .{});
        for (palette.colors[0..16], 0..) |color, i| {
            std.debug.print("{d:2}: ({d:3},{d:3},{d:3})\n", .{ i, color[0], color[1], color[2] });
        }
    } else if (std.mem.startsWith(u8, name, "E") and std.mem.endsWith(u8, name, "M")) {
        // Show map info
        var map = try wad_file.readMap(name, wad_file.allocator);
        defer map.deinit();

        std.debug.print("\nMap data:\n", .{});
        std.debug.print("Vertices: {d}\n", .{map.vertices.len});
        std.debug.print("Linedefs: {d}\n", .{map.linedefs.len});
        std.debug.print("Sectors: {d}\n", .{map.sectors.len});

        // Show first few vertices
        if (map.vertices.len > 0) {
            std.debug.print("\nFirst 5 vertices:\n", .{});
            for (map.vertices[0..@min(5, map.vertices.len)]) |vertex| {
                std.debug.print("  ({d}, {d})\n", .{ vertex.x, vertex.y });
            }
        }
    } else {
        // Show hex dump for unknown lump types
        std.debug.print("\nFirst 64 bytes (hex):\n", .{});
        var i: usize = 0;
        while (i < @min(64, data.len)) : (i += 1) {
            if (i % 16 == 0) std.debug.print("\n{x:0>4}: ", .{i});
            std.debug.print("{x:0>2} ", .{data[i]});
        }
        std.debug.print("\n\nFirst 64 bytes (ASCII):\n", .{});
        i = 0;
        while (i < @min(64, data.len)) : (i += 1) {
            if (i % 16 == 0) std.debug.print("\n{x:0>4}: ", .{i});
            const c = data[i];
            if (std.ascii.isPrint(c)) {
                std.debug.print("{c} ", .{c});
            } else {
                std.debug.print(". ", .{});
            }
        }
        std.debug.print("\n", .{});
    }
}
