const std = @import("std");
const zig_serial = @import("serial");

const application = @import("./gui/application.zig");
const command = @import("./command/command.zig");
const channel = @import("./oscilloscope/channel.zig");
const waveform = @import("./oscilloscope/waveform.zig");

pub fn main() !void {
    var serial = try std.fs.cwd().openFile("\\\\.\\COM2", .{ .mode = .read_write });
    var gpa = std.heap.GeneralPurposeAllocator(. {}){};
    const alloc = gpa.allocator();
    // defer serial.close();

    try application.Application.init();

    try zig_serial.configureSerialPort(serial, zig_serial.SerialConfig {
        .baud_rate = 115200,
        .word_size = .eight,
        .parity = .none,
        .stop_bits = .two,
        .handshake = .hardware
    });

    _ = try command.sendCommand(alloc, serial, command.Command.INIT, "");

    var result = try command.sendCommand(alloc, serial, command.Command.CH1_READ, "");
    std.debug.print("{b:8}\n", .{ result[4] });
    const ch = channel.createChannel(1, result[4]);
    std.debug.print("{?}", .{ ch });

    result = try command.sendCommand(alloc, serial, command.Command.WAVEFORM_PREAMBLE, "");
    std.debug.print("{b:8}\n", .{ result });
    const waveform_preamble = waveform.createWaveformPreamble(result[7..17]);
    std.debug.print("{?}", .{ waveform_preamble });

    const readArgs = [_]u8{ 0, 0, 0, 8, ' ', '\r', '\n' };
    result = try command.sendCommand(alloc, serial, command.Command.READ_WAVEFORM1, &readArgs);

    const voltages = try alloc.alloc(f32, 4096);
    const Y1Pos = waveform_preamble.y1_pos;

    var i: usize = 0;
    var j: f32 = 0;
    for (result[11..2059]) |data| {
        const dataAsInt: i16 = @as(i16, data);

        // HAMEG, Description of interface commands - page 18
        //
        // Calculating the voltage of the sampled signal form:
        // Given:  UN : Voltage value of the Nth sample
        //         25 : Y resolution per Div. (see WFMPRE?)
        //         Y1Pos : Y1 position of the signal form (see WFMPRE? YY YY)
        //         ByteN : Value of the signal form byte ( see RDWFM1 XX)
        //         V/Div : Attenuator setting (e.g.: 5mV)
        //
        // Calculation without taking the Y1 position into account:
        //      UN = (ByteN - 128)/25 * V/Div
        //
        // With this method it is only possible to evaluate the voltage difference of the acquired signal, since there is no
        // reference (Zero voltage). In order to calculate the absolute voltage of the sample one should include the Y
        // position in the calculations.
        //      UN = (ByteN - 128 - Y1Pos)/25 * V/Div 
        const resultInt: f32 = @as(f32, @floatFromInt(dataAsInt - 128 - Y1Pos)) / 25; // As per HAMEG documentation

        voltages[i] = j;
        voltages[i+1] = resultInt * ch.div_mapped;

        i += 2;
        j += 500;
    }

    std.debug.print("{d:.6}", .{ voltages });

    _ = try command.sendCommand(alloc, serial, command.Command.REMOTE_EXIT, "");
    alloc.free(result);
    serial.close();
}

test "simple test" {
    
}
