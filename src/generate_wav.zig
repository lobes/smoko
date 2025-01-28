const std = @import("std");

// WAV file header structure
const WavHeader = struct {
    // RIFF header
    riff_header: [4]u8 = "RIFF".*,
    chunk_size: u32 = 0, // Will be filled later
    wave_header: [4]u8 = "WAVE".*,

    // fmt subchunk
    fmt_header: [4]u8 = "fmt ".*,
    fmt_chunk_size: u32 = 16,
    audio_format: u16 = 1, // PCM = 1
    num_channels: u16 = 1, // Mono = 1
    sample_rate: u32 = 44100,
    byte_rate: u32 = 0, // Will be filled later
    block_align: u16 = 0, // Will be filled later
    bits_per_sample: u16 = 16,

    // data subchunk
    data_header: [4]u8 = "data".*,
    data_chunk_size: u32 = 0, // Will be filled later

    pub fn write(self: *const WavHeader, writer: anytype) !void {
        // Write RIFF header
        try writer.writeAll(&self.riff_header);
        try writer.writeInt(u32, self.chunk_size, .little);
        try writer.writeAll(&self.wave_header);

        // Write fmt subchunk
        try writer.writeAll(&self.fmt_header);
        try writer.writeInt(u32, self.fmt_chunk_size, .little);
        try writer.writeInt(u16, self.audio_format, .little);
        try writer.writeInt(u16, self.num_channels, .little);
        try writer.writeInt(u32, self.sample_rate, .little);
        try writer.writeInt(u32, self.byte_rate, .little);
        try writer.writeInt(u16, self.block_align, .little);
        try writer.writeInt(u16, self.bits_per_sample, .little);

        // Write data subchunk
        try writer.writeAll(&self.data_header);
        try writer.writeInt(u32, self.data_chunk_size, .little);
    }
};

pub fn main() !void {
    // Create allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parameters for the sine wave
    const duration_seconds: f32 = 2.0;
    const frequency: f32 = 440.0; // A4 note
    const amplitude: f32 = 0.5;
    const sample_rate: u32 = 44100;
    const num_samples = @as(usize, @intFromFloat(duration_seconds * @as(f32, @floatFromInt(sample_rate))));

    // Create samples array
    const samples = try allocator.alloc(i16, num_samples);
    defer allocator.free(samples);

    // Generate sine wave
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(sample_rate));
        const value = amplitude * @sin(2.0 * std.math.pi * frequency * t);
        sample.* = @as(i16, @intFromFloat(value * 32767.0)); // Convert to 16-bit
    }

    // Create WAV header
    var header = WavHeader{};
    header.bits_per_sample = 16;
    header.num_channels = 1;
    header.sample_rate = sample_rate;
    header.block_align = @as(u16, @intCast(header.num_channels * header.bits_per_sample / 8));
    header.byte_rate = header.sample_rate * header.block_align;
    header.data_chunk_size = @as(u32, @intCast(num_samples * header.block_align));
    header.chunk_size = header.data_chunk_size + 36; // 36 = size of header minus first 8 bytes

    // Open file for writing
    const file = try std.fs.cwd().createFile("zig-out/bin/sample.wav", .{});
    defer file.close();

    // Create buffered writer
    var buffered_writer = std.io.bufferedWriter(file.writer());
    const writer = buffered_writer.writer();

    // Write header
    try header.write(writer);

    // Write samples in little-endian format
    for (samples) |sample| {
        try writer.writeInt(i16, sample, .little);
    }

    // Flush any remaining buffered data
    try buffered_writer.flush();

    std.debug.print("Generated sample.wav: {d}Hz sine wave, {d} seconds\n", .{ frequency, duration_seconds });
}
