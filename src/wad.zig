const std = @import("std");

pub const WadError = error{
    InvalidMagic,
    InvalidLump,
    LumpNotFound,
    EndOfFile,
    InvalidPalette,
    InvalidTexture,
    InvalidPatch,
    InvalidMap,
};

pub const WadType = enum {
    IWAD,
    PWAD,

    pub fn fromMagic(magic: []const u8) !WadType {
        if (std.mem.eql(u8, magic, "IWAD")) return .IWAD;
        if (std.mem.eql(u8, magic, "PWAD")) return .PWAD;
        return WadError.InvalidMagic;
    }
};

pub const WadHeader = struct {
    wad_type: WadType,
    num_lumps: u32,
    info_table_offset: u32,

    pub fn read(data: []const u8) !WadHeader {
        if (data.len < 12) return WadError.InvalidMagic;
        return WadHeader{
            .wad_type = try WadType.fromMagic(data[0..4]),
            .num_lumps = @as(u32, data[4]) |
                @as(u32, data[5]) << 8 |
                @as(u32, data[6]) << 16 |
                @as(u32, data[7]) << 24,
            .info_table_offset = @as(u32, data[8]) |
                @as(u32, data[9]) << 8 |
                @as(u32, data[10]) << 16 |
                @as(u32, data[11]) << 24,
        };
    }
};

pub const WadLump = struct {
    offset: u32,
    size: u32,
    name: [8]u8,
    data: ?[]const u8, // Lazy-loaded data

    pub fn read(reader: anytype) !WadLump {
        return WadLump{
            .offset = try reader.readIntLittle(u32),
            .size = try reader.readIntLittle(u32),
            .name = try reader.readBytesNoEof(8),
            .data = null,
        };
    }

    pub fn getName(self: WadLump) []const u8 {
        // Find the first null terminator or end of name
        var end: usize = 0;
        while (end < 8 and self.name[end] != 0) : (end += 1) {}
        return self.name[0..end];
    }
};

pub const Palette = struct {
    colors: [256][3]u8, // 256 RGB colors

    pub fn fromLump(data: []const u8) !Palette {
        if (data.len < 768) return WadError.InvalidPalette;
        var pal: Palette = undefined;

        // Copy RGB values manually
        for (0..256) |i| {
            pal.colors[i][0] = data[i * 3]; // R
            pal.colors[i][1] = data[i * 3 + 1]; // G
            pal.colors[i][2] = data[i * 3 + 2]; // B
        }

        return pal;
    }
};

pub const Patch = struct {
    width: u16,
    height: u16,
    left_offset: i16,
    top_offset: i16,
    data: []const u8,

    pub fn fromLump(data: []const u8) !Patch {
        if (data.len < 8) return WadError.InvalidPatch;
        return Patch{
            .width = std.mem.readIntLittle(u16, data[0..2]),
            .height = std.mem.readIntLittle(u16, data[2..4]),
            .left_offset = std.mem.readIntLittle(i16, data[4..6]),
            .top_offset = std.mem.readIntLittle(i16, data[6..8]),
            .data = data[8..],
        };
    }
};

pub const MapVertex = struct {
    x: i16,
    y: i16,
};

pub const MapLinedef = struct {
    start_vertex: u16,
    end_vertex: u16,
    flags: u16,
    special_type: u16,
    sector_tag: u16,
    right_sidedef: u16,
    left_sidedef: u16,
};

pub const MapSector = struct {
    floor_height: i16,
    ceiling_height: i16,
    floor_texture: [8]u8,
    ceiling_texture: [8]u8,
    light_level: u16,
    special_type: u16,
    tag: u16,
};

pub const Map = struct {
    name: []const u8,
    vertices: []const MapVertex,
    linedefs: []const MapLinedef,
    sectors: []const MapSector,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Map) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.linedefs);
        self.allocator.free(self.sectors);
    }
};

pub const Wad = struct {
    header: WadHeader,
    lumps: []WadLump,
    data: []u8,
    allocator: std.mem.Allocator,

    pub fn load(path: []const u8, allocator: std.mem.Allocator) !Wad {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        // Get file size
        const size = try file.getEndPos();
        if (size < 12) return WadError.InvalidMagic;

        // Read entire file into memory for faster access (matching transcript approach)
        const data = try allocator.alloc(u8, @intCast(size));
        errdefer allocator.free(data);

        const bytes_read = try file.readAll(data);
        if (bytes_read != size) return WadError.EndOfFile;

        // Read header directly from buffer
        const header = try WadHeader.read(data);

        // Read directory entries
        var lumps = try allocator.alloc(WadLump, header.num_lumps);
        errdefer allocator.free(lumps);

        var i: usize = 0;
        while (i < header.num_lumps) : (i += 1) {
            const entry_offset = header.info_table_offset + (i * 16);
            if (entry_offset + 16 > size) return WadError.InvalidLump;

            // Read each field manually like in the transcript
            const lump_offset = @as(u32, data[entry_offset]) |
                @as(u32, data[entry_offset + 1]) << 8 |
                @as(u32, data[entry_offset + 2]) << 16 |
                @as(u32, data[entry_offset + 3]) << 24;

            const lump_size = @as(u32, data[entry_offset + 4]) |
                @as(u32, data[entry_offset + 5]) << 8 |
                @as(u32, data[entry_offset + 6]) << 16 |
                @as(u32, data[entry_offset + 7]) << 24;

            var name: [8]u8 = undefined;
            @memcpy(&name, data[entry_offset + 8 ..][0..8]);

            // Debug print raw bytes
            std.debug.print("Lump {d} raw bytes: ", .{i});
            for (name) |b| {
                std.debug.print("{x:0>2} ", .{b});
            }
            std.debug.print("\n", .{});

            // Clean up name - replace 0 bytes with spaces
            for (&name) |*c| {
                if (c.* == 0) c.* = ' ';
            }

            // Trim trailing spaces
            var end: usize = 8;
            while (end > 0 and name[end - 1] == ' ') : (end -= 1) {}

            std.debug.print("Lump {d} name: {s}\n", .{ i, name[0..end] });

            lumps[i] = WadLump{
                .offset = lump_offset,
                .size = lump_size,
                .name = name,
                .data = null,
            };
        }

        return Wad{
            .header = header,
            .lumps = lumps,
            .data = data,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Wad) void {
        self.allocator.free(self.lumps);
        self.allocator.free(self.data);
    }

    pub fn findLump(self: Wad, name: []const u8) ?WadLump {
        // Convert name to uppercase and pad with spaces
        var search_name: [8]u8 = .{' '} ** 8;
        const len = @min(name.len, 8);
        for (name[0..len], 0..) |c, i| {
            search_name[i] = std.ascii.toUpper(c);
        }

        std.debug.print("Looking for lump: {s}\n", .{name});
        for (self.lumps) |lump| {
            // Compare exact 8 bytes
            if (std.mem.eql(u8, &lump.name, &search_name)) {
                return lump;
            }
        }
        return null;
    }

    pub fn readLump(self: Wad, lump: WadLump) []const u8 {
        return self.data[lump.offset .. lump.offset + lump.size];
    }

    pub fn readLumpByName(self: Wad, name: []const u8) ![]const u8 {
        const lump = self.findLump(name) orelse return WadError.LumpNotFound;
        return self.readLump(lump);
    }

    pub fn readPalette(self: Wad) !Palette {
        const data = try self.readLumpByName("PLAYPAL");
        return Palette.fromLump(data);
    }

    pub fn readMap(self: Wad, name: []const u8, allocator: std.mem.Allocator) !Map {
        // Find map marker lump
        const map_lump = self.findLump(name) orelse return WadError.LumpNotFound;

        // Map lumps follow a specific order: VERTEXES, LINEDEFS, SIDEDEFS, SECTORS...
        var current_index: usize = 0;
        for (self.lumps, 0..) |lump, i| {
            if (lump.offset == map_lump.offset) {
                current_index = i + 1; // Start at next lump
                break;
            }
        }

        // Read vertices
        const vertex_data = try self.readLumpByName("VERTEXES");
        const num_vertices = @divExact(vertex_data.len, @sizeOf(MapVertex));
        const vertices = try allocator.alloc(MapVertex, num_vertices);

        // Copy vertices manually
        var vertex_index: usize = 0;
        while (vertex_index < num_vertices) : (vertex_index += 1) {
            const base = vertex_index * 4; // Each vertex is 4 bytes (2 i16s)
            vertices[vertex_index] = .{
                .x = @as(i16, @bitCast(@as(u16, vertex_data[base]) |
                    @as(u16, vertex_data[base + 1]) << 8)),
                .y = @as(i16, @bitCast(@as(u16, vertex_data[base + 2]) |
                    @as(u16, vertex_data[base + 3]) << 8)),
            };
        }

        // Read linedefs
        const linedef_data = try self.readLumpByName("LINEDEFS");
        const num_linedefs = @divExact(linedef_data.len, @sizeOf(MapLinedef));
        const linedefs = try allocator.alloc(MapLinedef, num_linedefs);

        // Copy linedefs manually
        var linedef_index: usize = 0;
        while (linedef_index < num_linedefs) : (linedef_index += 1) {
            const base = linedef_index * 14; // Each linedef is 14 bytes
            linedefs[linedef_index] = .{
                .start_vertex = @as(u16, linedef_data[base]) |
                    @as(u16, linedef_data[base + 1]) << 8,
                .end_vertex = @as(u16, linedef_data[base + 2]) |
                    @as(u16, linedef_data[base + 3]) << 8,
                .flags = @as(u16, linedef_data[base + 4]) |
                    @as(u16, linedef_data[base + 5]) << 8,
                .special_type = @as(u16, linedef_data[base + 6]) |
                    @as(u16, linedef_data[base + 7]) << 8,
                .sector_tag = @as(u16, linedef_data[base + 8]) |
                    @as(u16, linedef_data[base + 9]) << 8,
                .right_sidedef = @as(u16, linedef_data[base + 10]) |
                    @as(u16, linedef_data[base + 11]) << 8,
                .left_sidedef = @as(u16, linedef_data[base + 12]) |
                    @as(u16, linedef_data[base + 13]) << 8,
            };
        }

        // Read sectors
        const sector_data = try self.readLumpByName("SECTORS");
        const num_sectors = @divExact(sector_data.len, @sizeOf(MapSector));
        const sectors = try allocator.alloc(MapSector, num_sectors);

        // Copy sectors manually
        var sector_index: usize = 0;
        while (sector_index < num_sectors) : (sector_index += 1) {
            const base = sector_index * 26; // Each sector is 26 bytes
            sectors[sector_index] = .{
                .floor_height = @as(i16, @bitCast(@as(u16, sector_data[base]) |
                    @as(u16, sector_data[base + 1]) << 8)),
                .ceiling_height = @as(i16, @bitCast(@as(u16, sector_data[base + 2]) |
                    @as(u16, sector_data[base + 3]) << 8)),
                .floor_texture = sector_data[base + 4 .. base + 12][0..8].*,
                .ceiling_texture = sector_data[base + 12 .. base + 20][0..8].*,
                .light_level = @as(u16, sector_data[base + 20]) |
                    @as(u16, sector_data[base + 21]) << 8,
                .special_type = @as(u16, sector_data[base + 22]) |
                    @as(u16, sector_data[base + 23]) << 8,
                .tag = @as(u16, sector_data[base + 24]) |
                    @as(u16, sector_data[base + 25]) << 8,
            };
        }

        return Map{
            .name = name,
            .vertices = vertices,
            .linedefs = linedefs,
            .sectors = sectors,
            .allocator = allocator,
        };
    }

    pub fn readPatch(self: Wad, name: []const u8) !Patch {
        const data = try self.readLumpByName(name);
        return Patch.fromLump(data);
    }
};

// Testing
test "wad loading" {
    const allocator = std.testing.allocator;
    var wad = try Wad.load("src/wads/doom.wad", allocator);
    defer wad.deinit();

    try std.testing.expectEqual(wad.header.wad_type, .IWAD);
    try std.testing.expect(wad.header.num_lumps > 0);

    // Print first few lumps like in transcript
    std.debug.print("\nFirst 5 lumps:\n", .{});
    for (wad.lumps[0..@min(5, wad.lumps.len)]) |lump| {
        std.debug.print("{s}: offset={d}, size={d}\n", .{
            lump.getName(),
            lump.offset,
            lump.size,
        });
    }
}

test "read palette" {
    const allocator = std.testing.allocator;
    var wad = try Wad.load("src/wads/doom.wad", allocator);
    defer wad.deinit();

    const palette = try wad.readPalette();
    try std.testing.expectEqual(palette.colors.len, 256);
}

test "read map" {
    const allocator = std.testing.allocator;
    var wad = try Wad.load("src/wads/doom.wad", allocator);
    defer wad.deinit();

    var map = try wad.readMap("E1M1", allocator);
    defer map.deinit();

    try std.testing.expect(map.vertices.len > 0);
    try std.testing.expect(map.linedefs.len > 0);
    try std.testing.expect(map.sectors.len > 0);
}
