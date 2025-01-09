const std = @import("std");
const photo_processor = @import("photo_processor");

test "convert photo to ASCII" {
    const allocator = std.heap.page_allocator;
    
    // Example input: path to a sample photo
    const input_path = "test_resources/sample_photo.jpg";
    
    // Expected output: ASCII representation (this should match actual expected output)
    const expected_ascii = "@#S%?*+;:,.";
    
    // Call the function to convert photo to ASCII
    const ascii_result = try photo_processor.convert_to_ascii(allocator, input_path);
    
    defer std.heap.page_allocator.free(ascii_result);
    
    try std.testing.expect(ascii_result == expected_ascii);
}