const std = @import("std");

pub const Channel = struct {
    id: u2,
    gnd: bool,
    ac: bool,
    inv: bool,
    on: bool,
    div: u4,
    div_mapped: f32
};

pub fn createChannel(id: u2, config: u8) Channel {
    std.debug.print("{b:8}\n", .{ config << 4 });
    return Channel{
        .id = id,
        .gnd = (config >> 7 & 1) != 0,
        .ac = (config >> 6 & 1) != 0,
        .inv = (config >> 5 & 1) != 0,
        .on = (config >> 4 & 1) != 0,
        .div = @truncate(config),
        .div_mapped = mapVoltsPerDiv(@truncate(config))
    };
}

fn mapVoltsPerDiv(config_value: u4) f32 {
    return switch (config_value) {
        0 => 0.001,
        1 => 0.002,
        2 => 0.005,
        3 => 0.01,
        4 => 0.02,
        5 => 0.05,
        6 => 0.1,
        7 => 0.2,
        8 => 0.5,
        9 => 1,
        10 => 2,
        11 => 5,
        12 => 10,
        13 => 20,
        else => 0
    };
}
