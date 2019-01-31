class Gtkx3 < Formula
  desc "Toolkit for creating graphical user interfaces"
  homepage "https://gtk.org/"
  url "https://download.gnome.org/sources/gtk+/3.24/gtk+-3.24.3.tar.xz"
  sha256 "5708fa534d964b1fb9a69d15758729d51b9a438471d4612dc153f595904803bd"
  revision 5

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
  patch do
    url "https://gitlab.gnome.org/GNOME/gtk/commit/ecfb540dabc58a5daef9c2f49230ae0f6f5c940e.diff"
    sha256 "1ac20e99a161941b9ce779194468f8ccfacdf21a05662f7b500e9edd8ccebd4e"
  end

  # see https://gitlab.gnome.org/GNOME/gtk/issues/1600
  patch :DATA

  # see https://gitlab.gnome.org/GNOME/gtk/issues/1618
  patch do
    url "https://gitlab.gnome.org/GNOME/gtk/commit/cfad43b80d15328f2e82ccc677ce634bd32a5560.diff"
    sha256 "75f981cef20dbba9a56d843519a2f8fdc12ad88f4b4ced06150ceed6540886c6"
  end

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
