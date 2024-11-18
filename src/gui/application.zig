const std = @import("std");
const gtk = @import("gtk.zig");

pub const Application = struct {
    fn activate(app: *gtk.GtkApplication, _: gtk.gpointer) void {
        const window: *gtk.GtkWidget = gtk.gtk_application_window_new(app);
        const windowPtr: *gtk.GtkWindow = @ptrCast(window);

        var gpa = std.heap.GeneralPurposeAllocator(. {}){};
        const alloc = gpa.allocator();

        load_css(app, alloc);

        const list: *gtk.GtkWidget = gtk.gtk_list_box_new();
        gtk.gtk_window_set_child(@ptrCast(window), @ptrCast(list));

        gtk.gtk_widget_set_halign(@ptrCast(list), gtk.GTK_ALIGN_START);
        gtk.gtk_widget_set_valign(@ptrCast(list), gtk.GTK_ALIGN_BASELINE);

        const button = gtk.gtk_button_new_from_icon_name("go-home");
        gtk.gtk_list_box_append(@ptrCast(list), @ptrCast(button));

        gtk.gtk_window_set_title(windowPtr, "neoMEG");
        gtk.gtk_window_set_default_size(windowPtr, 800, 600);
        gtk.gtk_window_present(windowPtr);
    }

    fn load_css(_: *gtk.GtkApplication, alloc: std.mem.Allocator) void {
        const cssFilename = "themes/default.css";

        var result: []u8 = undefined;
        if (std.fs.selfExeDirPathAlloc(alloc)) |path| {
            result = path;
        } else |_| {
            result = "";
        }

        const paths = [_][]const u8 {result, cssFilename};

        const css_path: [:0]u8 = std.fs.path.joinZ(alloc, &paths) catch |err| switch(err) {
            else => undefined
        };

        const css_provider: *gtk.GtkCssProvider = gtk.gtk_css_provider_new();
        gtk.gtk_style_context_add_provider_for_display(gtk.gdk_display_get_default(), @ptrCast(css_provider), gtk.GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
        gtk.gtk_css_provider_load_from_file(@ptrCast(css_provider), gtk.g_file_new_for_path(@ptrCast(css_path)));
    }

    pub fn main() u8 {
        const app = gtk.gtk_application_new("org.gtk.example", gtk.G_APPLICATION_FLAGS_NONE);
        defer gtk.g_object_unref(app);

        _ = gtk.g_signal_connect_(app, "activate", @ptrCast(&activate), null);
        const status: i32 = gtk.g_application_run(@ptrCast(app), 0, null);
        
        return @intCast(status);
    }
};
