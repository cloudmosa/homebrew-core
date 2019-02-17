class Gtkx3 < Formula
  desc "Toolkit for creating graphical user interfaces"
  homepage "https://gtk.org/"
  url "https://download.gnome.org/sources/gtk+/3.24/gtk+-3.24.5.tar.xz"
  sha256 "0be5fb0d302bc3de26ab58c32990d895831e2b7c7418d0ffea1206d6a3ddb02f"
  revision 2

  bottle do
    sha256 "48b4596d4755c9ac359e26c2330775cfb3b3def44009ab88d895e5f861f80f46" => :mojave
    sha256 "192dbd991b55e9949e16b936a692ba735ba2ea6dc4f52ce57f2edbe11f62f53e" => :high_sierra
    sha256 "d5bd79eeb30c1ac888693e129dcc0397e40025c62d616e90f5faf2662cb159df" => :sierra
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
  # https://gitlab.gnome.org/GNOME/gtk/merge_requests/531
  patch do
    url "https://gitlab.gnome.org/GNOME/gtk/commit/23471feb9f56b137367ff3bec2267ce543f5422e.diff"
    sha256 "4547d9116a42edb36a5eaa0f51f9664dccd1a2735da39e99d354949988e089a8"
  end

  # see https://gitlab.gnome.org/GNOME/gtk/issues/1618
  # https://gitlab.gnome.org/GNOME/gtk/merge_requests/532
  patch do
    url "https://gitlab.gnome.org/GNOME/gtk/commit/cfad43b80d15328f2e82ccc677ce634bd32a5560.diff"
    sha256 "75f981cef20dbba9a56d843519a2f8fdc12ad88f4b4ced06150ceed6540886c6"
  end

  # Fix crash after close a fullscreen window.
  # https://gitlab.gnome.org/GNOME/gtk/merge_requests/545
  patch do
    url "https://gitlab.gnome.org/GNOME/gtk/commit/7c88b88c67070cc15ac6cbc7e7479c6b23691b4a.diff"
    sha256 "aa02b7951ceff194c3a63043ffc96a3446ed103df6d0d7b0d3af94d099fb1261"
  end

  def install
    # Force GTK+3 set MACOSX_DEPLOYMENT_TARGET to 10.10, or the minimal version to be the set to
    # the builder machine's OS version.
    ENV.append "CFLAGS", "-mmacosx-version-min=10.10"

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
