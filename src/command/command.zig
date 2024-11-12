const std = @import("std");
const serial = @import("serial");

pub const Command = enum {
    INIT,
    REMOTE_EXIT,
    READ_WAVEFORM1,
    READ_WAVEFORM2,
    AUTOSET,
    WAVEFORM_PREAMBLE,
    CH1_READ,
    CH2_READ,
};

fn mapCommandToString(command: Command) ![]const u8 {
    return switch (command) {
        .INIT => " \r\n",
        .REMOTE_EXIT => "RM0\r\n",
        .AUTOSET => "AUTOSET\r\n",
        .READ_WAVEFORM1 => "RDWFM1:",
        .READ_WAVEFORM2 => "RDWFM2:",
        .WAVEFORM_PREAMBLE => "WFMPRE?\r\n",
        .CH1_READ => "CH1?\r\n",
        .CH2_READ => "CH2?\r\n"
    };
}

fn expectedBytes(command: Command) u16 {
    return switch (command) {
        .INIT => 3,
        .REMOTE_EXIT => 3,
        .READ_WAVEFORM1 => 2059,
        .READ_WAVEFORM2 => 2059,
        .AUTOSET => 3,
        .WAVEFORM_PREAMBLE => 17,
        .CH1_READ => 5,
        .CH2_READ => 1
    };
}

pub fn sendCommand(alloc: std.mem.Allocator, connection: std.fs.File, command: Command, args: []const u8) ![]u8 {
    const name = try mapCommandToString(command);
    const bytes = expectedBytes(command);
    try connection.writer().writeAll(name);
    try connection.writer().writeAll(args);
    std.debug.print("Sending command {s}\n", .{ @tagName(command) });

    var result = try alloc.alloc(u8, bytes);

    for (0..bytes) |i| {
        result[i] = try connection.reader().readByte();
        // std.debug.print("Reading byte for {X}", .{ result[i] });
    }
    if (command == Command.AUTOSET) std.time.sleep(1000000000);
    return result;
}

