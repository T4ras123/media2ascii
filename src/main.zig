// src/main.zig
const std = @import("std");
const video_processor = @import("video_processor.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const src_path = "src/example.mp4";
    const dest_path = "src/example_saved.mp4";

    var video = video_processor.loadVideo(allocator, src_path) catch |err| {
        std.debug.print("Failed to load video: {}\n", .{err});
        return;
    };
    defer video.deinit();

    video_processor.saveVideo(video, dest_path) catch |err| {
        std.debug.print("Failed to save video: {}\n", .{err});
        return;
    };

    std.debug.print("Video loaded and saved successfully.\n", .{});
}
