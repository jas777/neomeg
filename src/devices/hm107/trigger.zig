const std = @import("std");

// Present in the VERtical MODE byte
pub const TriggerSource = enum {
    CH1,
    CH2,
    ALT, // Alternating
    EXT // External
};

// Bits D0-D2 in trigger byte
pub const TriggerCoupling = enum {
    AC, // DC content suppressed
    DC, // Peak value detection inactive
    HF, // High frequencies (>~ 50 kHz)
    NR, // High frequency noise rejected
    LF, // Low frequencies (<~ 1.5 kHz)
    TVLINE, // TV signal, line pulse triggering
    TVFIELD, // TV signal, frame pulse triggering
    LINE // Mains triggering
};

// Bit D4 in trigger byte
pub const TriggerMode = enum {
    AUTO,
    NORM
};

// Bit D7 in trigger byte
pub const TimebaseSlope = enum {
    POSITIVE, // _/¯
    NEGATIVE // ¯\_
};

pub const Timebase = struct {
    slope: TimebaseSlope,
    level: u10
};

pub const Trigger = struct {
    source: TriggerSource,
    coupling: TriggerCoupling,
    mode: TriggerMode,
    timebaseA: Timebase,
    timebaseB: Timebase
};

fn vermode_to_source(vermode: u8) TriggerSource {
    if (((vermode >> 7) & 1) == 1) return TriggerSource.ALT;
    if ((vermode << 6) == 0) return TriggerSource.CH1;
    if ((vermode << 6) == 64) return TriggerSource.CH2;
    return TriggerSource.EXT;
}

pub fn create_trigger(trig_data: u8, tb_b: u8, vermode: u8) Trigger {
    return Trigger {
        .source = vermode_to_source(vermode),
        .coupling = @enumFromInt(trig_data & 7),
        .mode = @enumFromInt((trig_data >> 4) & 1),
        .timebaseA = Timebase { .slope = @enumFromInt((trig_data >> 7) & 1), .level = 0 },
        .timebaseB = Timebase { .slope = @enumFromInt((tb_b >> 7) & 1), .level = 0 },
    };
}
