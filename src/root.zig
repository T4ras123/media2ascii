const std = @import("std");
const ascii_converter = @import("ascii_converter");
const video_processor = @import("video_processor");
const photo_processor = @import("photo_processor");

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <image_path>\n", .{args[0]});
        return;
    }

    const image_path = args[1];
    const ascii = try photo_processor.convert_to_ascii(allocator, image_path);
    std.debug.print("{s}\n", .{ascii});
}