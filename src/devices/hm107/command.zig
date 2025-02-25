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
    VAR1_READ,
    VAR2_READ,
    TBA_READ,
    TBB_READ,
    TRIG_READ,
    VERMODE_READ,
    TRGLEVA_READ,
    TRGLEVB_READ,
    VERS,
    ID,
    
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
        .CH2_READ => "CH2?\r\n",
        .VAR1_READ => "CH1VAR?\r\n",
        .VAR2_READ => "CH2VAR?\r\n",
        .TBA_READ => "TBA?\r\n",
        .TBB_READ => "TBB?\r\n",
        .TRIG_READ => "TRIG?\r\n",
        .VERMODE_READ => "VERMODE?\r\n",
        .TRGLEVA_READ => "TRGLEVA?\r\n",
        .TRGLEVB_READ => "TRGLEVB?\r\n",
        .VERS => "VERS?\r\n",
        .ID => "ID?\r\n",
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
        .CH2_READ => 5,
        .VAR1_READ => 8,
        .VAR2_READ => 8,
        .TBA_READ => 5,
        .TBB_READ => 5,
        .TRIG_READ => 6,
        .VERMODE_READ => 9,
        .TRGLEVA_READ => 10,
        .TRGLEVB_READ => 10,
        .VERS => 20,
        .ID => 30
    };
}

pub fn sendCommand(alloc: std.mem.Allocator, connection: std.fs.File, command: Command, args: []const u8) ![]u8 {
    const name = try mapCommandToString(command);
    const bytes = expectedBytes(command);
    try connection.writer().writeAll(name);
    try connection.writer().writeAll(args);
    std.debug.print("Sending command {s} -> ", .{ @tagName(command) });

    var result = try alloc.alloc(u8, bytes);

    for (0..bytes) |i| {
        result[i] = try connection.reader().readByte();
    }
    if (command == Command.AUTOSET) std.time.sleep(1000000000);
    std.debug.print("{s}", .{ result });
    return result;
}

