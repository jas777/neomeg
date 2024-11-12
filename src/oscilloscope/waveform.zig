pub const WaveformPreamble = struct {
    trig_addr: u16,
    x_res: u16,
    y_res: u16,
    y1_pos: i16,
    y2_pos: i16
};

pub fn createWaveformPreamble(data: []const u8) WaveformPreamble {
    return WaveformPreamble{
        .trig_addr = @as(u16, data[0]) | (@as(u16, data[1]) << 8),
        .x_res = @as(u16, data[2]) | (@as(u16, data[3]) << 8),
        .y_res = @as(u16, data[4]) | (@as(u16, data[5]) << 8),
        .y1_pos = @as(i16, @as(i16, data[6]) | (@as(i16, data[7]) << 8)),
        .y2_pos = @as(i16, @as(i16, data[8]) | (@as(i16, data[9]) << 8)),
    };
}
