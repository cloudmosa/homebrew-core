class Gtkx3 < Formula
  desc "Toolkit for creating graphical user interfaces"
  homepage "https://gtk.org/"
  url "https://download.gnome.org/sources/gtk+/3.24/gtk+-3.24.3.tar.xz"
  sha256 "5708fa534d964b1fb9a69d15758729d51b9a438471d4612dc153f595904803bd"
  revision 2

  bottle do
    sha256 "0ff37c31034d15b1e145cdbc430aeb5b0d4f745ddf0048ec2620f840c0f0f1c7" => :mojave
    sha256 "0337bac40272f2b545646fe02f111132003665a6c92697043b1b53a6aac926a4" => :high_sierra
    sha256 "69fe35bf0c07eb3a1c219eaf1ce9f8caebcb6de70a6c015da03752cc993b5432" => :sierra
  end

  depends_on "gobject-introspection" => :build
  depends_on "pkg-config" => :build
  depends_on "atk"
  depends_on "gdk-pixbuf"
  depends_on "glib"
  depends_on "gsettings-desktop-schemas"
  depends_on "hicolor-icon-theme"
  depends_on "libepoxy"
  depends_on "pango"

  # see https://gitlab.gnome.org/GNOME/gtk/issues/1593
  patch :DATA

  def install
    args = %W[
      --enable-debug=minimal
      --disable-dependency-tracking
      --prefix=#{prefix}
      --disable-glibtest
      --enable-introspection=yes
      --disable-schemas-compile
      --enable-quartz-backend
      --disable-x11-backend
    ]

    system "./configure", *args
    # necessary to avoid gtk-update-icon-cache not being found during make install
    bin.mkpath
    ENV.prepend_path "PATH", bin
    system "make", "install"
    # Prevent a conflict between this and Gtk+2
    mv bin/"gtk-update-icon-cache", bin/"gtk3-update-icon-cache"
  end

  def post_install
    system "#{Formula["glib"].opt_bin}/glib-compile-schemas", "#{HOMEBREW_PREFIX}/share/glib-2.0/schemas"
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <gtk/gtk.h>

      int main(int argc, char *argv[]) {
        gtk_disable_setlocale();
        return 0;
      }
    EOS
    atk = Formula["atk"]
    cairo = Formula["cairo"]
    fontconfig = Formula["fontconfig"]
    freetype = Formula["freetype"]
    gdk_pixbuf = Formula["gdk-pixbuf"]
    gettext = Formula["gettext"]
    glib = Formula["glib"]
    libepoxy = Formula["libepoxy"]
    libpng = Formula["libpng"]
    pango = Formula["pango"]
    pixman = Formula["pixman"]
    flags = %W[
      -I#{atk.opt_include}/atk-1.0
      -I#{cairo.opt_include}/cairo
      -I#{fontconfig.opt_include}
      -I#{freetype.opt_include}/freetype2
      -I#{gdk_pixbuf.opt_include}/gdk-pixbuf-2.0
      -I#{gettext.opt_include}
      -I#{glib.opt_include}/gio-unix-2.0/
      -I#{glib.opt_include}/glib-2.0
      -I#{glib.opt_lib}/glib-2.0/include
      -I#{include}
      -I#{include}/gtk-3.0
      -I#{libepoxy.opt_include}
      -I#{libpng.opt_include}/libpng16
      -I#{pango.opt_include}/pango-1.0
      -I#{pixman.opt_include}/pixman-1
      -D_REENTRANT
      -L#{atk.opt_lib}
      -L#{cairo.opt_lib}
      -L#{gdk_pixbuf.opt_lib}
      -L#{gettext.opt_lib}
      -L#{glib.opt_lib}
      -L#{lib}
      -L#{pango.opt_lib}
      -latk-1.0
      -lcairo
      -lcairo-gobject
      -lgdk-3
      -lgdk_pixbuf-2.0
      -lgio-2.0
      -lglib-2.0
      -lgobject-2.0
      -lgtk-3
      -lintl
      -lpango-1.0
      -lpangocairo-1.0
    ]
    system ENV.cc, "test.c", "-o", "test", *flags
    system "./test"
  end
end

__END__

https://gitlab.gnome.org/GNOME/gtk/issues/1593
Fix bug that gdk_monitor_get_workarea() always return workarea for main screen.
Fix bug that gdk_monitor_get_geometry() return wrong gemotry that is NOT based on GdkScreen coordination,
this bug causes gdk_display_get_monitor_at_point() can not find correct monitor at point.

https://gitlab.gnome.org/GNOME/gtk/issues/1600
Fix bug it crash when use mouse to select item in input method cadinate window

---
diff -u gtk+-3.24.2-origin/gdk/quartz/gdkdisplay-quartz.c gtk+-3.24.2/gdk/quartz/gdkdisplay-quartz.c
--- gtk+-3.24.2-origin/gdk/quartz/gdkdisplay-quartz.c	2018-12-12 06:08:38.000000000 -0800
+++ gtk+-3.24.2/gdk/quartz/gdkdisplay-quartz.c	2019-01-15 10:56:58.000000000 -0800
@@ -235,7 +235,7 @@
 }
 
 static void
-configure_monitor (GdkMonitor *monitor)
+configure_monitor (GdkMonitor *monitor, const GdkRectangle *screen_rect)
 {
   GdkQuartzMonitor *quartz_monitor = GDK_QUARTZ_MONITOR (monitor);
   CGSize disp_size = CGDisplayScreenSize (quartz_monitor->id);
@@ -246,6 +246,13 @@
                                 (int)trunc (disp_bounds.origin.y),
                                 (int)trunc (disp_bounds.size.width),
                                 (int)trunc (disp_bounds.size.height)};
+
+  if (screen_rect)
+    {
+      disp_geometry.x = disp_geometry.x - screen_rect->x;
+      disp_geometry.y = screen_rect->height - (disp_geometry.y + disp_geometry.height) + screen_rect->y;
+    }
+
   CGDisplayModeRef mode = CGDisplayCopyDisplayMode (quartz_monitor->id);
   gint refresh_rate = (int)trunc (CGDisplayModeGetRefreshRate (mode));
 
@@ -265,6 +272,7 @@
 {
   GdkQuartzDisplay *display = data;
   GdkQuartzMonitor *monitor;
+  GdkQuartzScreen *screen;
 
   /* Ignore the begin configuration signal. */
   if (flags & kCGDisplayBeginConfigurationFlag)
@@ -274,6 +282,8 @@
                kCGDisplaySetMainFlag | kCGDisplayDesktopShapeChangedFlag |
                kCGDisplayMirrorFlag | kCGDisplayUnMirrorFlag))
     {
+      GdkRectangle screen_rect;
+
       monitor = g_hash_table_lookup (display->monitors,
                                      GINT_TO_POINTER (cg_display));
       if (!monitor)
@@ -286,7 +296,14 @@
           gdk_display_monitor_added (GDK_DISPLAY (display),
                                      GDK_MONITOR (monitor));
         }
-      configure_monitor (GDK_MONITOR (monitor));
+
+      screen = GDK_QUARTZ_SCREEN (gdk_display_get_default_screen (display));
+      screen_rect.x = screen->min_x;
+      screen_rect.y = screen->min_y;
+      screen_rect.width = screen->width;
+      screen_rect.height = screen->height;
+
+      configure_monitor (GDK_MONITOR (monitor), &screen_rect);
     }
   else if (flags & (kCGDisplayRemoveFlag |  kCGDisplayDisabledFlag))
     {
@@ -351,14 +368,30 @@
 static void
 gdk_quartz_display_init (GdkQuartzDisplay *display)
 {
+  int min_x = 0, min_y = 0, max_x = 0, max_y = 0;
   uint32_t max_displays = 0, disp;
   CGDirectDisplayID *displays;
+  GdkRectangle screen_rect;
 
   CGGetActiveDisplayList (0, NULL, &max_displays);
   display->monitors = g_hash_table_new_full (g_direct_hash, NULL,
                                              NULL, g_object_unref);
   displays = g_new0 (CGDirectDisplayID, max_displays);
   CGGetActiveDisplayList (max_displays, displays, &max_displays);
+
+  for (disp = 0; disp < max_displays; ++disp)
+    {
+      CGRect bounds = CGDisplayBounds (displays[disp]);
+      min_x = MIN (min_x, (int)trunc (bounds.origin.x));
+      min_y = MIN (min_y, (int)trunc (bounds.origin.y));
+      max_x = MAX (max_x, (int)trunc (bounds.origin.x + bounds.size.width));
+      max_y = MAX (max_y, (int)trunc (bounds.origin.y + bounds.size.height));
+    }
+  screen_rect.x = min_x;
+  screen_rect.y = min_y;
+  screen_rect.width = max_x - min_x;
+  screen_rect.height = max_y - min_y;
+
   for (disp = 0; disp < max_displays; ++disp)
     {
       GdkQuartzMonitor *monitor = g_object_new (GDK_TYPE_QUARTZ_MONITOR,
@@ -366,7 +399,7 @@
       monitor->id = displays[disp];
       g_hash_table_insert (display->monitors, GINT_TO_POINTER (monitor->id),
                            monitor);
-      configure_monitor (GDK_MONITOR (monitor));
+      configure_monitor (GDK_MONITOR (monitor), &screen_rect);
     }
   CGDisplayRegisterReconfigurationCallback (display_reconfiguration_callback,
                                             display);
diff -u gtk+-3.24.2-origin/gdk/quartz/gdkmonitor-quartz.c gtk+-3.24.2/gdk/quartz/gdkmonitor-quartz.c
--- gtk+-3.24.2-origin/gdk/quartz/gdkmonitor-quartz.c	2018-12-12 06:08:38.000000000 -0800
+++ gtk+-3.24.2/gdk/quartz/gdkmonitor-quartz.c	2019-01-15 11:14:52.000000000 -0800
@@ -30,24 +30,30 @@
 gdk_quartz_monitor_get_workarea (GdkMonitor   *monitor,
                                  GdkRectangle *dest)
 {
+  int i;
   GdkQuartzScreen *quartz_screen = GDK_QUARTZ_SCREEN(gdk_display_get_default_screen (monitor->display));
   GdkQuartzMonitor *quartz_monitor = GDK_QUARTZ_MONITOR(monitor);
 
+  *dest = monitor->geometry;
+
   GDK_QUARTZ_ALLOC_POOL;
 
   NSArray *array = [NSScreen screens];
-  if (quartz_monitor->monitor_num < [array count])
+  for (i = 0; i < [array count]; i++)
     {
-      NSScreen *screen = [array objectAtIndex:quartz_monitor->monitor_num];
-      NSRect rect = [screen visibleFrame];
-
-      dest->x = rect.origin.x - quartz_screen->min_x;
-      dest->y = quartz_screen->height - (rect.origin.y + rect.size.height) + quartz_screen->min_y;
-      dest->width = rect.size.width;
-      dest->height = rect.size.height;
+      NSScreen *screen = [array objectAtIndex:i];
+      NSNumber *screen_num = screen.deviceDescription[@"NSScreenNumber"];
+      CGDirectDisplayID display_id = screen_num.unsignedIntValue;
+      if (display_id == quartz_monitor->id)
+        {
+          NSRect rect = [screen visibleFrame];
+          dest->x = rect.origin.x - quartz_screen->min_x;
+          dest->y = quartz_screen->height - (rect.origin.y + rect.size.height) + quartz_screen->min_y;
+          dest->width = rect.size.width;
+          dest->height = rect.size.height;
+          break;
+        }
     }
-  else
-    *dest = monitor->geometry;
 
   GDK_QUARTZ_RELEASE_POOL;
 }
diff -u gtk+-3.24.2-origin/gdk/quartz/gdkmonitor-quartz.h gtk+-3.24.2/gdk/quartz/gdkmonitor-quartz.h
--- gtk+-3.24.2-origin/gdk/quartz/gdkmonitor-quartz.h	2018-12-12 06:08:38.000000000 -0800
+++ gtk+-3.24.2/gdk/quartz/gdkmonitor-quartz.h	2019-01-15 11:13:00.000000000 -0800
@@ -29,7 +29,6 @@
 struct _GdkQuartzMonitor
 {
   GdkMonitor parent;
-  gint monitor_num;
   CGDirectDisplayID id;
 };
 
diff -u gtk+-3.24.2-origin/gdk/quartz/gdkscreen-quartz.c gtk+-3.24.2/gdk/quartz/gdkscreen-quartz.c
--- gtk+-3.24.2-origin/gdk/quartz/gdkscreen-quartz.c	2018-12-12 06:08:38.000000000 -0800
+++ gtk+-3.24.2/gdk/quartz/gdkscreen-quartz.c	2019-01-15 10:09:53.000000000 -0800
@@ -120,9 +120,9 @@
 static void
 gdk_quartz_screen_calculate_layout (GdkQuartzScreen *screen)
 {
-  int i, monitors;
+  uint32_t max_displays = 0, disp;
+  CGDirectDisplayID *displays;
   int max_x, max_y;
-  GdkDisplay *display = gdk_screen_get_display (GDK_SCREEN (screen));
 
   screen->width = 0;
   screen->height = 0;
@@ -136,22 +136,20 @@
    * covered by the monitors.  From this we can deduce the width
    * and height of the root screen.
    */
-  monitors = gdk_display_get_n_monitors (display);
-  for (i = 0; i < monitors; ++i)
-    {
-      GdkQuartzMonitor *monitor =
-           GDK_QUARTZ_MONITOR (gdk_display_get_monitor (display, i));
-      GdkRectangle rect;
-
-      gdk_monitor_get_geometry (GDK_MONITOR (monitor), &rect);
-      screen->min_x = MIN (screen->min_x, rect.x);
-      max_x = MAX (max_x, rect.x + rect.width);
-
-      screen->min_y = MIN (screen->min_y, rect.y);
-      max_y = MAX (max_y, rect.y + rect.height);
+  CGGetActiveDisplayList (0, NULL, &max_displays);
+  displays = g_new0 (CGDirectDisplayID, max_displays);
+  CGGetActiveDisplayList (max_displays, displays, &max_displays);
 
-      screen->mm_height += GDK_MONITOR (monitor)->height_mm;
-      screen->mm_width += GDK_MONITOR (monitor)->width_mm;
+  for (disp = 0; disp < max_displays; ++disp)
+    {
+      CGRect bounds = CGDisplayBounds (displays[disp]);
+      CGSize disp_size = CGDisplayScreenSize (displays[disp]);
+      screen->min_x = MIN (screen->min_x, (int)trunc (bounds.origin.x));
+      screen->min_y = MIN (screen->min_y, (int)trunc (bounds.origin.y));
+      max_x = MAX (max_x, (int)trunc (bounds.origin.x + bounds.size.width));
+      max_y = MAX (max_y, (int)trunc (bounds.origin.y + bounds.size.height));
+      screen->mm_width += (int)trunc (disp_size.height);
+      screen->mm_height += (int)trunc (disp_size.width);
     }
 
   screen->width = max_x - screen->min_x;
diff -u gtk+-3.24.3/modules/input/imquartz.c gtk+-3.24.3-working/modules/input/imquartz.c
--- gtk+-3.24.3/modules/input/imquartz.c        2019-01-13 19:06:51.000000000 -0800
+++ gtk+-3.24.3-working/modules/input/imquartz.c        2019-01-16 17:54:36.000000000 -0800
@@ -196,7 +196,7 @@
     {
       if (event->hardware_keycode == 0 && event->keyval == 0xffffff)
         /* update text input changes by mouse events */
-        return output_result (context, win);
+        return output_result (context, event->window);
       else
         return gtk_im_context_filter_keypress (qc->slave, event);
     }
