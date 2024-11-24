const std = @import("std");
const gtk = @import("../../gui/gtk.zig");
const serial = @import("../../communication/serial.zig");
const channel = @import("channel.zig");
const waveform = @import("waveform.zig");
const command = @import("command.zig");

const hm107 = @embedFile("../../ui/hm107.ui");

fn intToString(int: f32, buf: []u8) ![]const u8 {
    return try std.fmt.bufPrint(buf, "{d:.1}", .{int});
}

pub const Hm107Device = struct {
    alloc: std.mem.Allocator,
    id: u8,
    name: []const u8 = "HM 107 Series Device",
    connection: std.fs.File,
    
    ch1: channel.Channel,
    ch2: channel.Channel,

    waveform_preamble: waveform.WaveformPreamble,

    pub fn init(port_name: []const u8) !Hm107Device {
        var gpa = std.heap.GeneralPurposeAllocator(. {}){};
        const alloc = gpa.allocator();

        const connection = try std.fs.cwd().openFile(port_name, .{ .mode = .read_write });
        defer connection.close();

        try serial.configureSerialPort(connection, serial.SerialConfig {
            .baud_rate = 115200,
            .word_size = .eight,
            .parity = .none,
            .stop_bits = .two,
            .handshake = .hardware
        });

        _ = try command.sendCommand(alloc, connection, command.Command.INIT, "");

        var result = try command.sendCommand(alloc, connection, command.Command.CH1_READ, "");
        const ch1 = channel.create_channel(1, result[4]);

        result = try command.sendCommand(alloc, connection, command.Command.CH2_READ, "");
        const ch2 = channel.create_channel(2, result[4]);

        result = try command.sendCommand(alloc, connection, command.Command.WAVEFORM_PREAMBLE, "");
        const waveform_preamble = waveform.create_waveform_preamble(result[7..17]);
        
        _ = try command.sendCommand(alloc, connection, command.Command.REMOTE_EXIT, "");

        return Hm107Device {
            .id = 1,
            .alloc = alloc,
            .connection = connection,
            .ch1 = ch1,
            .ch2 = ch2,
            .waveform_preamble = waveform_preamble
        };
    }

    pub fn set_page(port_name: []const u8, navigation: [*c]gtk.GtkWidget) !void {
        const device = try Hm107Device.init(port_name);

        const hm107C: [*c]const u8 = hm107;
        var err: [*c]gtk.GError = null;
        const builder: ?*gtk.GtkBuilder = gtk.gtk_builder_new();

        if (gtk.gtk_builder_add_from_string(@ptrCast(builder), hm107C, hm107.len, &err) == 0) {
            gtk.g_printerr("Error loading file: %s\n", err.*.message);
            gtk.g_clear_error(&err);
        }

        const page: *gtk.adw.AdwNavigationPage = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "view"));
        gtk.adw.adw_navigation_split_view_set_content(@ptrCast(navigation), @ptrCast(page));

        const ch1_volts: *gtk.GtkDropDown = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "ch1_volts_div"));
        gtk.gtk_drop_down_set_selected(@ptrCast(ch1_volts), device.ch1.div);

        const ch2_volts: *gtk.GtkDropDown = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "ch2_volts_div"));
        gtk.gtk_drop_down_set_selected(@ptrCast(ch2_volts), device.ch2.div);
    }
};