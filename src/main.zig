const std = @import("std");
const zig_serial = @import("./communication/serial.zig");

const application = @import("./gui/application.zig");

pub fn main() !void {
    // var serial = try std.fs.cwd().openFile("\\\\.\\COM1", .{ .mode = .read_write });
    // defer serial.close();

    _ = application.Application.main();
}

test "simple test" {}
