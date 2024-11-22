const std = @import("std");
const gtk = @import("gtk.zig");

const adwaita = @embedFile("../ui/adwaita.css");
const defaultCss = @embedFile("../ui/default.css");
const applicationUi = @embedFile("../ui/application.ui");

pub const Application = struct {
    fn activate(app: *gtk.GtkApplication, _: gtk.gpointer) void {
        load_css();

        const builder: ?*gtk.GtkBuilder = gtk.gtk_builder_new();
        var err: [*c]gtk.GError = null;
        const applicationUiC: [*c]const u8 = applicationUi;

        std.debug.print("{s}", .{applicationUiC});

        if (gtk.gtk_builder_add_from_string(@ptrCast(builder), applicationUiC, applicationUi.len, &err) == 0) {
            gtk.g_printerr("Error loading file: %s\n", err.*.message);
            gtk.g_clear_error(&err);
        }

        const window = gtk.gtk_builder_get_object(@constCast(builder), "window");
        const windowPtr: *gtk.GtkWindow = @ptrCast(window);
        gtk.gtk_window_set_application(@ptrCast(windowPtr), @ptrCast(app));
        gtk.gtk_window_present(@ptrCast(windowPtr));
    }

    fn load_css() void {
        const defaultCssC: [*c]const u8 = defaultCss;
        // const adwaitaC: [*c]const u8 = adwaita;

        // const css_provider2: *gtk.GtkCssProvider = gtk.gtk_css_provider_new();
        // gtk.gtk_style_context_add_provider_for_display(gtk.gdk_display_get_default(), @ptrCast(css_provider2), gtk.GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
        // gtk.gtk_css_provider_load_from_string(@ptrCast(css_provider2), adwaitaC);

        const css_provider: *gtk.GtkCssProvider = gtk.gtk_css_provider_new();
        gtk.gtk_style_context_add_provider_for_display(gtk.gdk_display_get_default(), @ptrCast(css_provider), gtk.GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
        gtk.gtk_css_provider_load_from_string(@ptrCast(css_provider), defaultCssC);

    }

    pub fn main() u8 {
        const app = gtk.gtk_application_new("com.neomeg", gtk.G_APPLICATION_FLAGS_NONE);
        defer gtk.g_object_unref(app);

        _ = gtk.g_signal_connect_(app, "activate", @ptrCast(&activate), null);
        const status: i32 = gtk.g_application_run(@ptrCast(app), 0, null);
        
        return @intCast(status);
    }
};
