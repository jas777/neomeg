const std = @import("std");
const gtk = @import("gtk.zig");

const Hm107 = @import("../devices/hm107/hm107.zig");

const adwaita = @embedFile("../ui/adwaita.css");
const defaultCss = @embedFile("../ui/default.css");
const applicationUi = @embedFile("../ui/application.ui");

pub const Application = struct {
    fn activate(app: *gtk.adw.AdwApplication, _: gtk.gpointer) void {
        load_css();

        const builder: ?*gtk.GtkBuilder = gtk.gtk_builder_new();
        const scope: ?*gtk.GtkBuilderScope = gtk.gtk_builder_cscope_new();
        var err: [*c]gtk.GError = null;
        const applicationUiC: [*c]const u8 = applicationUi;

        gtk.gtk_builder_cscope_add_callback_symbol(@ptrCast(@alignCast(scope)), "on_new_device_click", @ptrCast(&on_new_device_click));
        gtk.gtk_builder_set_scope(builder, scope);

        if (gtk.gtk_builder_add_from_string(@ptrCast(builder), applicationUiC, applicationUi.len, &err) == 0) {
            gtk.g_printerr("Error loading file: %s\n", err.*.message);
            gtk.g_clear_error(&err);
        }

        const window = gtk.gtk_builder_get_object(@constCast(builder), "window");
        const windowPtr: *gtk.GtkWindow = @ptrCast(window);

        gtk.gtk_window_set_application(@ptrCast(windowPtr), @ptrCast(app));
        gtk.gtk_window_present(@ptrCast(windowPtr));
    }

    fn on_new_device_click(widget: *gtk.GtkWidget, _: gtk.gpointer) void {
        // Create a new dialog window
        const popup = gtk.gtk_window_new();
        gtk.gtk_window_set_title(@ptrCast(popup), "New Device");
        gtk.gtk_window_set_default_size(@ptrCast(popup), 400, 200);
        const parent_window = gtk.gtk_widget_get_ancestor(widget, gtk.gtk_window_get_type());

        // FIXME: Just fooling around with charts for now
        if (parent_window) |win| {
            gtk.gtk_window_set_transient_for(@ptrCast(popup), @ptrCast(win));
        }

        gtk.gtk_window_set_modal(@ptrCast(popup), 1);

        // Prevent parent window from closing when the dialog closes
        gtk.gtk_window_set_destroy_with_parent(@ptrCast(popup), 0);

        // Add a label to the popup
        const label = gtk.gtk_label_new("Select a device to connect");
        gtk.gtk_window_set_child(@ptrCast(popup), @ptrCast(label));

        const chart = gtk.gtk_chart_new();
        gtk.gtk_chart_set_type(@ptrCast(chart), gtk.GTK_CHART_TYPE_LINE);
        gtk.gtk_chart_set_title(@ptrCast(chart), "Title");
        gtk.gtk_chart_set_label(@ptrCast(chart), "Label");
        gtk.gtk_chart_set_x_label(@ptrCast(chart), "X label [ ]");
        gtk.gtk_chart_set_y_label(@ptrCast(chart), "Y label [ ]");
        gtk.gtk_chart_set_x_max(@ptrCast(chart), 100);
        gtk.gtk_chart_set_y_max(@ptrCast(chart), 10);
        gtk.gtk_chart_set_width(@ptrCast(chart), 800);
        gtk.gtk_window_set_child(@ptrCast(popup), @ptrCast(chart));

        // Show the popup
        gtk.gtk_window_present(@ptrCast(popup));
        // TODO: Add device choice, HM107 for tesing purposes
        const navigation = gtk.gtk_widget_get_parent(
            gtk.gtk_widget_get_parent(
                gtk.gtk_widget_get_parent(
                    gtk.gtk_widget_get_parent(
                        gtk.gtk_widget_get_parent(
                            gtk.gtk_widget_get_parent(
                                gtk.gtk_widget_get_parent(@ptrCast(widget))))))));

        Hm107.Hm107Device.set_page("\\\\.\\COM2", navigation) catch |err| switch (err) {
            else => std.debug.print("Failed to connect", .{})
        };
    }

    fn load_css() void {
        const defaultCssC: [*c]const u8 = defaultCss;

        const css_provider: *gtk.GtkCssProvider = gtk.gtk_css_provider_new();
        gtk.gtk_style_context_add_provider_for_display(gtk.gdk_display_get_default(), @ptrCast(css_provider), gtk.GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
        gtk.gtk_css_provider_load_from_string(@ptrCast(css_provider), defaultCssC);
    }

    pub fn main() u8 {
        const app = gtk.adw.adw_application_new("com.neomeg", gtk.G_APPLICATION_FLAGS_NONE);
        defer gtk.g_object_unref(app);

        _ = gtk.g_signal_connect_(app, "activate", @ptrCast(&activate), null);
        const status: i32 = gtk.g_application_run(@ptrCast(app), 0, null);
        
        return @intCast(status);
    }
};
