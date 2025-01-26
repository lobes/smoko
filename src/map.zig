const std = @import("std");
const wad = @import("wad.zig");

pub const Vertex = packed struct {
    x: i16,
    y: i16,
};

pub const LineDef = packed struct {
    start_vertex: u16,
    end_vertex: u16,
    flags: u16,
    special_type: u16,
    sector_tag: u16,
    right_sidedef: u16,
    left_sidedef: u16,
};

pub const SideDef = packed struct {
    x_offset: i16,
    y_offset: i16,
    upper_texture: [8]u8,
    lower_texture: [8]u8,
    middle_texture: [8]u8,
    sector: u16,
};

pub const Sector = packed struct {
    floor_height: i16,
    ceiling_height: i16,
    floor_texture: [8]u8,
    ceiling_texture: [8]u8,
    light_level: u16,
    special_type: u16,
    tag: u16,
};

pub const Thing = packed struct {
    x: i16,
    y: i16,
    angle: u16,
    type: u16,
    flags: u16,
};

pub const Map = struct {
    vertices: []Vertex,
    linedefs: []LineDef,
    sidedefs: []SideDef,
    sectors: []Sector,
    things: []Thing,
    allocator: std.mem.Allocator,

    pub fn loadFromWad(allocator: std.mem.Allocator, wad_file: *wad.Wad, map_name: []const u8) !Map {
        // First find the map marker lump
        _ = try wad_file.getLump(map_name);

        // Load vertices
        const vertices_lump = try wad_file.getLump("VERTEXES");
        defer allocator.free(vertices_lump);
        const vertices = try allocator.dupe(Vertex, std.mem.bytesAsSlice(Vertex, vertices_lump));

        // Load linedefs
        const linedefs_lump = try wad_file.getLump("LINEDEFS");
        defer allocator.free(linedefs_lump);
        const linedefs = try allocator.dupe(LineDef, std.mem.bytesAsSlice(LineDef, linedefs_lump));

        // Load sidedefs
        const sidedefs_lump = try wad_file.getLump("SIDEDEFS");
        defer allocator.free(sidedefs_lump);
        const sidedefs = try allocator.dupe(SideDef, std.mem.bytesAsSlice(SideDef, sidedefs_lump));

        // Load sectors
        const sectors_lump = try wad_file.getLump("SECTORS");
        defer allocator.free(sectors_lump);
        const sectors = try allocator.dupe(Sector, std.mem.bytesAsSlice(Sector, sectors_lump));

        // Load things
        const things_lump = try wad_file.getLump("THINGS");
        defer allocator.free(things_lump);
        const things = try allocator.dupe(Thing, std.mem.bytesAsSlice(Thing, things_lump));

        return Map{
            .vertices = vertices,
            .linedefs = linedefs,
            .sidedefs = sidedefs,
            .sectors = sectors,
            .things = things,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Map) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.linedefs);
        self.allocator.free(self.sidedefs);
        self.allocator.free(self.sectors);
        self.allocator.free(self.things);
    }
};

test "map - load E1M1" {
    const allocator = std.testing.allocator;
    var wad_file = try wad.Wad.init(allocator, "src/wads/doom.wad");
    defer wad_file.deinit();

    var map = try Map.loadFromWad(allocator, &wad_file, "E1M1");
    defer map.deinit();

    try std.testing.expect(map.vertices.len > 0);
    try std.testing.expect(map.linedefs.len > 0);
    try std.testing.expect(map.sidedefs.len > 0);
    try std.testing.expect(map.sectors.len > 0);
    try std.testing.expect(map.things.len > 0);
}
