#include <gtk/gtk.h>
#include <gdk/gdkx.h>

void test_host_present(GtkWidget *canvas) {
	gtk_window_present(GTK_WINDOW(gtk_widget_get_toplevel(canvas)));
}

/* Queue native GTK events rather than invoking MaxGUI callbacks directly.
 * XTest input depends on compositor focus and is unreliable on remote XWayland. */
void test_host_input(GtkWidget *canvas, GtkWidget *field) {
	GdkWindow *window = gtk_widget_get_window(canvas);
	GdkSeat *seat = gdk_display_get_default_seat(gdk_window_get_display(window));
	for (int i = 0; i < 2; ++i) {
		GdkEvent *event = gdk_event_new(i ? GDK_BUTTON_RELEASE : GDK_BUTTON_PRESS);
		event->button.window = g_object_ref(window);
		event->button.time = GDK_CURRENT_TIME;
		event->button.x = 37;
		event->button.y = 49;
		event->button.button = 1;
		gdk_event_set_device(event, gdk_seat_get_pointer(seat));
		gdk_event_put(event);
		gdk_event_free(event);
	}
	gtk_widget_grab_focus(field);
	for (int i = 0; i < 2; ++i) {
		GdkEvent *event = gdk_event_new(i ? GDK_KEY_RELEASE : GDK_KEY_PRESS);
		event->key.window = g_object_ref(gtk_widget_get_window(gtk_widget_get_toplevel(field)));
		event->key.time = GDK_CURRENT_TIME;
		event->key.keyval = GDK_KEY_z;
		event->key.hardware_keycode = XKeysymToKeycode(gdk_x11_display_get_xdisplay(gdk_window_get_display(window)), XK_z);
		gdk_event_set_device(event, gdk_seat_get_keyboard(seat));
		gdk_event_put(event);
		gdk_event_free(event);
	}
	gtk_widget_queue_draw(canvas);
}

int test_host_detached(GtkWidget *canvas) {
	GdkWindow *window = gtk_widget_get_window(canvas);
	return window && !gdk_window_is_destroyed(window) && !g_object_get_data(G_OBJECT(window), "bmx.sdl3.attached");
}
