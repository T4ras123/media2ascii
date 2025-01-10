// tests/video_processor_test.zig
const std = @import("std");
const video_processor = @import("video_processor.zig");

test "load and save video without loss" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const original_path = "src/example.mp4";
    const copy_path = "src/example_copy.mp4";

    const video = try video_processor.loadVideo(allocator, original_path);
    defer video.deinit();

    try video_processor.saveVideo(video, copy_path);

    const original_file = try std.fs.cwd().openFile(original_path, .{});
    defer original_file.close();
    const copy_file = try std.fs.cwd().openFile(copy_path, .{});
    defer copy_file.close();

    const original_size = try original_file.getEndPos();
    const copy_size = try copy_file.getEndPos();
    try std.testing.expect(original_size == copy_size);

    const original_data = try allocator.alloc(u8, original_size);
    defer allocator.free(original_data);
    try original_file.readAll(original_data);

    const copy_data = try allocator.alloc(u8, copy_size);
    defer allocator.free(copy_data);
    try copy_file.readAll(copy_data);

    try std.testing.expect(std.mem.eql(u8, original_data, copy_data));
}