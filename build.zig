const std = @import("std");

pub fn build(b: *std.Build) void {
    // Configure the build target based on your environment (e.g., architecture, OS)
    const target = b.standardTargetOptions(.{});
    
    // Set the optimization level (e.g., Debug, ReleaseSafe, ReleaseFast)
    const optimize = b.standardOptimizeOption(.{});
    
    // Add the executable target with ExecutableOptions
    const exe = b.addExecutable(.{
        .name = "media2ascii",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkSystemLibrary("c"); // Link the C standard library if needed
    
    // Set the default build step to depend on the executable
    b.default_step.dependOn(&exe.step);
    
    // Add the test target with TestOptions
    const video_test = b.addTest(.{
        .name = "video_processor_test",
        .root_source_file = b.path("tests/video_processor_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    video_test.linkSystemLibrary("c"); // Link the C standard library if needed
}