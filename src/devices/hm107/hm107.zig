const std = @import("std");
const gtk = @import("../../gui/gtk.zig");
const serial = @import("../../communication/serial.zig");
const channel = @import("channel.zig");
const waveform = @import("waveform.zig");
const command = @import("command.zig");
const trig = @import("trigger.zig");

const hm107 = @embedFile("../../ui/hm107.ui");

fn intToString(int: f32, buf: []u8) ![]const u8 {
    return try std.fmt.bufPrint(buf, "{d:.1}", .{int});
}

pub const Hm107Device = struct {
    alloc: std.mem.Allocator,
    id: []const u8 = "4141214",
    firmware: []const u8 = "",
    name: []const u8 = "HM 107 Series Device",
    connection: std.fs.File,
    
    ch1: channel.Channel,
    ch2: channel.Channel,

    trigger: trig.Trigger,

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
        const ch1_var: u8 = (try command.sendCommand(alloc, connection, command.Command.VAR1_READ, ""))[7];
        const ch1 = channel.create_channel(1, result[4], ch1_var);

        result = try command.sendCommand(alloc, connection, command.Command.CH2_READ, "");
        const ch2_var: u8 = (try command.sendCommand(alloc, connection, command.Command.VAR2_READ, ""))[7];
        const ch2 = channel.create_channel(2, result[4], ch2_var);

        result = try command.sendCommand(alloc, connection, command.Command.WAVEFORM_PREAMBLE, "");
        const waveform_preamble = waveform.create_waveform_preamble(result[7..17]);

        result = try command.sendCommand(alloc, connection, command.Command.TRIG_READ, "");
        const trig_data: u8 = result[5];
        result = try command.sendCommand(alloc, connection, command.Command.TBB_READ, "");
        const tbb_data: u8 = result[4];
        result = try command.sendCommand(alloc, connection, command.Command.VERMODE_READ, "");
        const vermode: u8 = result[8];
        
        var model_split = std.mem.splitAny(u8, try command.sendCommand(alloc, connection, command.Command.ID, ""), " ");
        var model = model_split.next().?;

        var fw = try command.sendCommand(alloc, connection, command.Command.VERS, "");

        const device =  Hm107Device {
            .id = try alloc.dupeZ(u8, model[3..]),
            .firmware = try alloc.dupeZ(u8, fw[5..fw.len-2]),
            .alloc = alloc,
            .connection = connection,
            .ch1 = ch1,
            .ch2 = ch2,
            .waveform_preamble = waveform_preamble,
            .trigger = trig.create_trigger(trig_data, tbb_data, vermode),
        };

        std.debug.print("\n{s}\n{s}\n", .{ @tagName(device.trigger.timebaseA.slope), @tagName(device.trigger.timebaseB.slope) });

        _ = try command.sendCommand(alloc, connection, command.Command.REMOTE_EXIT, "");
        return device;
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

        const model_entry: *gtk.GtkEntry = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "model"));
        gtk.gtk_editable_set_text(@ptrCast(model_entry), @ptrCast(device.id));

        const firmware_entry: *gtk.GtkEntry = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "firmware"));
        gtk.gtk_editable_set_text(@ptrCast(firmware_entry), @ptrCast(device.firmware));

        // Channel 1

        const ch1_var: *gtk.GtkDropDown = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "ch1_var"));
        var buf: [8]u8 = undefined;
        const ch1_factor: f16 = channel.var_to_factor(device.ch1.ch_var);

        if (ch1_factor != 1.0) {
            gtk.gtk_widget_add_css_class(@ptrCast(@alignCast(ch1_var)), "warning");
        }

        _ = try std.fmt.bufPrintZ(&buf, "{d:.3}", .{ ch1_factor });
        gtk.gtk_editable_set_text(@ptrCast(ch1_var), @ptrCast(&buf));

        const ch2_var: *gtk.GtkDropDown = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "ch2_var"));
        buf = undefined;
        const ch2_factor: f16 = channel.var_to_factor(device.ch2.ch_var);

        const ch1_volts: *gtk.GtkDropDown = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "ch1_volts_div"));
        const ch1_volts_values: *gtk.GtkStringList = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "ch1_volts_div_values"));

        for (0..14) |i| {
            const adjusted_div: f16 = @floatCast(channel.map_volts_per_div(@intCast(i)) * ch1_factor);
            var adjusted_div_slice: [8]u8 = undefined;
            _ = try std.fmt.bufPrintZ(&adjusted_div_slice, "{d:.3}", .{ adjusted_div });
            gtk.gtk_string_list_append(@ptrCast(ch1_volts_values), @ptrCast(&adjusted_div_slice));
        }
        gtk.gtk_drop_down_set_selected(@ptrCast(ch1_volts), device.ch1.div);

        const ch1_ac: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "ch1_input"));
        const ch1_dc: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "ch1_dc"));
        const ch1_gnd: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "ch1_gnd"));

        if (device.ch1.ac and !device.ch2.gnd) gtk.gtk_check_button_set_active(@ptrCast(ch1_ac), 1)
        else if (!device.ch1.ac and !device.ch1.gnd) gtk.gtk_check_button_set_active(@ptrCast(ch1_dc), 1)
        else if (device.ch1.gnd) gtk.gtk_check_button_set_active(@ptrCast(ch1_gnd), 1);

        // Channel 2 TODO: Move into a separate function, no need for code doubling

        const ch2_volts: *gtk.GtkDropDown = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "ch2_volts_div"));
        const ch2_volts_values: *gtk.GtkStringList = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "ch2_volts_div_values"));

        for (0..14) |i| {
            const adjusted_div: f16 = @floatCast(channel.map_volts_per_div(@intCast(i)) * ch2_factor);
            var adjusted_div_slice: [8]u8 = undefined;
            _ = try std.fmt.bufPrintZ(&adjusted_div_slice, "{d:.3}", .{ adjusted_div });
            gtk.gtk_string_list_append(@ptrCast(ch2_volts_values), @ptrCast(&adjusted_div_slice));
        }
        gtk.gtk_drop_down_set_selected(@ptrCast(ch2_volts), device.ch2.div);

        if (ch2_factor != 1.0) {
            gtk.gtk_widget_add_css_class(@ptrCast(@alignCast(ch2_var)), "warning");
        }

        _ = try std.fmt.bufPrintZ(&buf, "{d:.3}", .{ ch2_factor });
        gtk.gtk_editable_set_text(@ptrCast(ch2_var), @ptrCast(&buf));

        const ch2_ac: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "ch2_input"));
        const ch2_dc: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "ch2_dc"));
        const ch2_gnd: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "ch2_gnd"));

        if (device.ch2.ac and !device.ch2.gnd) gtk.gtk_check_button_set_active(@ptrCast(ch2_ac), 1)
        else if (!device.ch2.ac and !device.ch2.gnd) gtk.gtk_check_button_set_active(@ptrCast(ch2_dc), 1)
        else if (device.ch2.gnd) gtk.gtk_check_button_set_active(@ptrCast(ch2_gnd), 1);

        // Trigger
        const trig_ch1: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "trigger_source"));
        const trig_ch2: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "trig_ch2"));
        const trig_alt: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "trig_alt"));
        const trig_ext: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "trig_ext"));

        switch (device.trigger.source) {
            .CH1 => gtk.gtk_check_button_set_active(@ptrCast(trig_ch1), 1),
            .CH2 => gtk.gtk_check_button_set_active(@ptrCast(trig_ch2), 1),
            .ALT => gtk.gtk_check_button_set_active(@ptrCast(trig_alt), 1),
            .EXT => gtk.gtk_check_button_set_active(@ptrCast(trig_ext), 1),
        }

        const trig_ac: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "trigger_coupling"));
        const trig_dc: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "trig_dc"));
        const trig_hf: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "trig_hf"));
        const trig_nr: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "trig_nr"));
        const trig_lf: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "trig_lf"));
        const trig_tvline: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "trig_tvline"));
        const trig_tvfield: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "trig_tvfield"));
        const trig_line: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "trig_line"));

        switch (device.trigger.coupling) {
            .AC => gtk.gtk_check_button_set_active(@ptrCast(trig_ac), 1),
            .DC => gtk.gtk_check_button_set_active(@ptrCast(trig_dc), 1),
            .HF => gtk.gtk_check_button_set_active(@ptrCast(trig_hf), 1),
            .NR => gtk.gtk_check_button_set_active(@ptrCast(trig_nr), 1),
            .LF => gtk.gtk_check_button_set_active(@ptrCast(trig_lf), 1),
            .TVLINE => gtk.gtk_check_button_set_active(@ptrCast(trig_tvline), 1),
            .TVFIELD => gtk.gtk_check_button_set_active(@ptrCast(trig_tvfield), 1),
            .LINE => gtk.gtk_check_button_set_active(@ptrCast(trig_line), 1),
        }

        const trig_mode: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "trigger_mode"));
        const trig_norm: *gtk.GtkCheckButton = @ptrCast(gtk.gtk_builder_get_object(@constCast(builder), "trig_norm"));

        switch (device.trigger.mode) {
            .AUTO => gtk.gtk_check_button_set_active(@ptrCast(trig_mode), 1),
            .NORM => gtk.gtk_check_button_set_active(@ptrCast(trig_norm), 1),
        }
    }
};
