const std = @import("std");
const zig_serial = @import("./communication/serial.zig");

const application = @import("./gui/application.zig");
const command = @import("./command/command.zig");
const channel = @import("./oscilloscope/channel.zig");
const waveform = @import("./oscilloscope/waveform.zig");

pub fn main() !void {
    // var serial = try std.fs.cwd().openFile("\\\\.\\COM1", .{ .mode = .read_write });
    // defer serial.close();

    _ = application.Application.main();
}

test "simple test" {}
