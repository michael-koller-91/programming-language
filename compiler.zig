const std = @import("std");
const print = @import("std").debug.print;

pub fn main() !void {
    const filename = "main.prola";

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();
    const content = try allocator.alloc(u8, (try file.stat()).size);
    _ = try std.fs.Dir.readFile(std.fs.cwd(), filename, content);
    defer allocator.free(content);

    print("{s}\n", .{content});
}
