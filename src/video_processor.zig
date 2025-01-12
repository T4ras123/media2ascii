const std = @import("std");

pub const Video = struct {
    data: []u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Video) void {
        self.allocator.free(self.data);
    }
};

pub const VideoError = error{
    FileOpenFailed,
    ReadFailed,
    WriteFailed,
    AllocationFailed,
};

pub fn loadVideo(allocator: std.mem.Allocator, path: []const u8) !Video {
    const file = try std.fs.cwd().openFile(path, .{}) catch VideoError.FileOpenFailed;
    defer file.close();
    const file_size = try file.getEndPos() catch VideoError.ReadFailed;
    const data = try allocator.alloc(u8, file_size) catch VideoError.AllocationFailed;
    defer allocator.free(data);
    _ = try file.readAll(data) catch VideoError.ReadFailed;
    return Video{
        .data = data,
        .allocator = allocator,
    };
}

pub fn saveVideo(video: Video, path: []const u8) !void {

    const file = try std.fs.cwd().createFile(path, .{ .truncate = true });

    defer file.close();

    try file.writeAll(video.data);
}