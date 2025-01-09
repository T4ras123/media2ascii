const std = @import("std");

pub const Image = struct {
    width: u32,
    height: u32,
    channels: u8,
    data: []u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Image) void {
        self.allocator.free(self.data);
    }
};

pub const ImageError = error{
    UnsupportedFormat,
    InvalidHeader,
    InvalidData,
    AllocationFailed,
    InvalidIDATChunk,
    InvalidColorType,
    InvalidBitDepth,
    DecompressionError,
    InvalidJPEGMarker,
    UnsupportedJPEGFormat,
    NoSpaceLeft
};

const PNGChunk = struct {
    length: u32,
    type: [4]u8,
    data: []u8,
    crc: u32,

    fn deinit(self: *PNGChunk, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};


const JPEGSegment = struct {
    marker: u8,
    length: u16,
    data: []u8,

    fn deinit(self: *JPEGSegment, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

const SliceWriter = struct {
    data: []u8,
    pos: usize,

    pub fn writeAll(self: *SliceWriter, buf: []const u8) !void {
        if (self.pos + buf.len > self.data.len)
            return ImageError.NoSpaceLeft;
        @memcpy(self.data[self.pos..self.pos + buf.len], buf);
        self.pos += buf.len;
    }
};

pub fn loadImage(alloc: std.mem.Allocator, path: []const u8) !Image {

    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var header_buffer: [8]u8 = undefined;
    const bytes_read = try file.read(&header_buffer);
    if (bytes_read != 8) return ImageError.InvalidHeader;

    // Check for PNG signature
    if (std.mem.eql(u8, header_buffer[0..8], "\x89PNG\r\n\x1a\n")) {
        return try loadPNG(alloc, file);
    }

    // Check for JPEG signature
    if (header_buffer[0] == 0xFF and header_buffer[1] == 0xD8) {
        return try loadJPEG(alloc, file);
    }

    else {
        return ImageError.UnsupportedFormat;
    }
}

fn readPNGChunk(allocator: std.mem.Allocator, file: std.fs.File) !PNGChunk {
    var chunk: PNGChunk = undefined;

    var length_buffer: [4]u8 = undefined;
    const bytes_read = try file.read(&length_buffer);
    if (bytes_read != 4) return ImageError.InvalidData;

    chunk.length = std.mem.readInt(u32, &length_buffer, .big);

    _ = try file.read(&chunk.type);

    chunk.data = try allocator.alloc(u8, chunk.length);
    errdefer allocator.free(chunk.data);

    const data_read = try file.read(chunk.data);
    if (data_read != chunk.length) {
        return ImageError.InvalidData;
    }

    var crc_buffer: [4]u8 = undefined;
    const crc_read = try file.read(&crc_buffer);
    if (crc_read != 4) return ImageError.InvalidData;

    chunk.crc = std.mem.readInt(u32, &crc_buffer, .big);

    return chunk;
}


fn loadPNG(allocator: std.mem.Allocator, file: std.fs.File) !Image {
    var width: u32 = 0;
    var height: u32 = 0;
    var bit_depth: u8 = 0;
    var color_type: u8 = 0;
    var compression: u8 = 0;
    var filter: u8 = 0;
    var interlace: u8 = 0;

    var compressed_data = std.ArrayList(u8).init(allocator);
    defer compressed_data.deinit();

    while (true) {
        var chunk = try readPNGChunk(allocator, file);
        defer chunk.deinit(allocator);

        if (std.mem.eql(u8, &chunk.type, "IHDR")) {
            if (chunk.length != 13) return ImageError.InvalidHeader;

            width = std.mem.readInt(u32, chunk.data[0..4], .big);
            height = std.mem.readInt(u32, chunk.data[4..8], .big);
            bit_depth = chunk.data[8];
            color_type = chunk.data[9];
            compression = chunk.data[10];
            filter = chunk.data[11];
            interlace = chunk.data[12];

            if (compression != 0 or filter != 0 or interlace != 0) {
                return ImageError.UnsupportedFormat;
            }
        } else if (std.mem.eql(u8, &chunk.type, "IDAT")) {
            try compressed_data.appendSlice(chunk.data);
        } else if (std.mem.eql(u8, &chunk.type, "IEND")) {
            break;
        } else {
            // Skip other chunk types
            continue;
        }
    }

    const channels: u8 = switch (color_type) {
        0 => 1,
        2 => 3,
        3 => 1,
        4 => 2,
        6 => 4,
        else => return ImageError.InvalidColorType,
    };

    const stride = width * channels;
    const data_size = (stride + 1) * height; 

    const image_data = try allocator.alloc(u8, data_size);

    var writer = SliceWriter{
        .data = image_data,
        .pos = 0,
    };

    var in_stream = std.io.fixedBufferStream(compressed_data.items);

    try std.compress.zlib.decompress(in_stream.reader(), &writer);

    if (writer.pos != image_data.len) {
        return ImageError.DecompressionError;
    }

    return Image{
        .width = width,
        .height = height,
        .channels = channels,
        .data = image_data,
        .allocator = allocator,
    };
}

fn readJPEGSegment(allocator: std.mem.Allocator, file: std.fs.File) !JPEGSegment {
    var segment: JPEGSegment = undefined;

    var marker_buffer: [2]u8 = undefined;
    _ = try file.read(&marker_buffer);
    
    if (marker_buffer[0] != 0xFF) {
        return ImageError.InvalidJPEGMarker;
    }
    segment.marker = marker_buffer[1];

    if (segment.marker != 0x01 and segment.marker < 0xD0 or segment.marker > 0xD9) {
        var length_buffer: [2]u8 = undefined;
        _ = try file.read(&length_buffer);
        segment.length = std.mem.readInt(u16, &length_buffer, .big);
        
        segment.length -= 2;

        segment.data = try allocator.alloc(u8, segment.length);
        _ = try file.read(segment.data);
    } else {
        segment.length = 0;
        segment.data = &[_]u8{};
    }

    return segment;
}

fn loadJPEG(allocator: std.mem.Allocator, file: std.fs.File) !Image {
    var width: u16 = 0;
    var height: u16 = 0;
    var components: u8 = 0;

    while (true) {
        var segment = try readJPEGSegment(allocator, file);
        defer segment.deinit(allocator);

        if (segment.marker == 0xC0) {
            if (segment.length < 6) {
                return ImageError.InvalidData;
            }

            components = segment.data[5];
            height = std.mem.readInt(u16, segment.data[1..3], .big);
            width = std.mem.readInt(u16, segment.data[3..5], .big);
            break;
        }

        if (segment.marker == 0xD9) {
            return ImageError.InvalidData;
        }
    }

    const data_size = width * height * components;

    const image_data = try allocator.alloc(u8, data_size);

    return Image{
        .width = width,
        .height = height,
        .channels = components,
        .data = image_data,
        .allocator = allocator,
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    {
        var image = loadImage(allocator, "./example.png") catch |err| {
            std.debug.print("Failed to load PNG: {}\n", .{err});
            return;
        };
        defer image.deinit();
        std.debug.print("Loaded PNG: {}x{} with {} channels\n", .{
            image.width, 
            image.height,
            image.channels
        });
    }

    {
        var image = loadImage(allocator, "./example.jpeg") catch |err| {
            std.debug.print("Failed to load JPEG: {}\n", .{err});
            return;
        };
        defer image.deinit();
        std.debug.print("Loaded JPEG: {}x{} with {} channels\n", .{
            image.width,
            image.height,
            image.channels
        });
    }
}
