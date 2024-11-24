const std = @import("std");
const Channel = @import("./channel.zig").Channel;

pub const WaveformPreamble = struct { trig_addr: u16, x_res: u16, y_res: u16, y1_pos: i16, y2_pos: i16 };

pub fn create_waveform_preamble(data: []const u8) WaveformPreamble {
    return WaveformPreamble{
        .trig_addr = @as(u16, data[0]) | (@as(u16, data[1]) << 8),
        .x_res = @as(u16, data[2]) | (@as(u16, data[3]) << 8),
        .y_res = @as(u16, data[4]) | (@as(u16, data[5]) << 8),
        .y1_pos = @as(i16, @as(i16, data[6]) | (@as(i16, data[7]) << 8)),
        .y2_pos = @as(i16, @as(i16, data[8]) | (@as(i16, data[9]) << 8)),
    };
}

//
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
//
pub fn waveform_voltages(alloc: std.mem.Allocator, preamble: WaveformPreamble, channel: Channel, signal: u8[2059]) [2048]f64 {
    const voltages = try alloc.alloc(f32, 4096);
    const Y1Pos = preamble.y1_pos;

    var i: usize = 0;
    var j: f32 = 0;
    for (signal[11..2059]) |data| {
        const dataAsInt: i16 = @as(i16, data);
        const resultInt: f32 = @as(f32, @floatFromInt(dataAsInt - 128 - Y1Pos)) / 25; // As per HAMEG documentation
        voltages[i] = j;
        voltages[i + 1] = resultInt * channel.div_mapped;
        i += 2;
        j += 500;
    }
}
