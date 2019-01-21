class Pango < Formula
  desc "Framework for layout and rendering of i18n text"
  homepage "https://www.pango.org/"
  url "https://download.gnome.org/sources/pango/1.42/pango-1.42.4.tar.xz"
  sha256 "1d2b74cd63e8bd41961f2f8d952355aa0f9be6002b52c8aa7699d9f5da597c9d"
  revision 2

  bottle do
    sha256 "16c404ecab2dcf3d6eda9b93fe512c0f6b90b0d73887f80da814bc5d470c1ef3" => :mojave
    sha256 "f1d5d2471ff6a0f6bdf643fd821d6d96fef211819ee080a0a6352554ce71fdb9" => :high_sierra
    sha256 "9800e829c90780dd7a31f3a1806bd92a25bafadc47506830eaefb148d4b71570" => :sierra
  end

  head do
    url "https://gitlab.gnome.org/GNOME/pango.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "gtk-doc" => :build
    depends_on "libtool" => :build
  end

  depends_on "gobject-introspection" => :build
  depends_on "pkg-config" => :build
  depends_on "cairo"
  depends_on "fontconfig"
  depends_on "fribidi"
  depends_on "glib"
  depends_on "harfbuzz"

  patch :DATA

  def install
    system "./autogen.sh" if build.head?
    system "./configure", "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}",
                          "--with-html-dir=#{share}/doc",
                          "--enable-introspection=yes",
                          "--enable-static",
                          "--without-xft"

    system "make"
    system "make", "install"
  end

  test do
    system "#{bin}/pango-view", "--version"
    (testpath/"test.c").write <<~EOS
      #include <pango/pangocairo.h>

      int main(int argc, char *argv[]) {
        PangoFontMap *fontmap;
        int n_families;
        PangoFontFamily **families;
        fontmap = pango_cairo_font_map_get_default();
        pango_font_map_list_families (fontmap, &families, &n_families);
        g_free(families);
        return 0;
      }
    EOS
    cairo = Formula["cairo"]
    fontconfig = Formula["fontconfig"]
    freetype = Formula["freetype"]
    gettext = Formula["gettext"]
    glib = Formula["glib"]
    libpng = Formula["libpng"]
    pixman = Formula["pixman"]
    flags = %W[
      -I#{cairo.opt_include}/cairo
      -I#{fontconfig.opt_include}
      -I#{freetype.opt_include}/freetype2
      -I#{gettext.opt_include}
      -I#{glib.opt_include}/glib-2.0
      -I#{glib.opt_lib}/glib-2.0/include
      -I#{include}/pango-1.0
      -I#{libpng.opt_include}/libpng16
      -I#{pixman.opt_include}/pixman-1
      -D_REENTRANT
      -L#{cairo.opt_lib}
      -L#{gettext.opt_lib}
      -L#{glib.opt_lib}
      -L#{lib}
      -lcairo
      -lglib-2.0
      -lgobject-2.0
      -lintl
      -lpango-1.0
      -lpangocairo-1.0
    ]
    system ENV.cc, "test.c", "-o", "test", *flags
    system "./test"
  end
end

__END__
For support color emoji on macOS, use "Apple Color Emoji" font for abstract font family "emoji".

---
diff -r -u pango-1.42.4-origin/pango/pangocoretext-fontmap.c pango-1.42.4/pango/pangocoretext-fontmap.c
--- pango-1.42.4-origin/pango/pangocoretext-fontmap.c	2018-08-05 19:47:22.000000000 -0700
+++ pango-1.42.4/pango/pangocoretext-fontmap.c	2019-01-17 14:42:03.000000000 -0800
@@ -1323,7 +1323,8 @@
 
       if (G_UNLIKELY (!fontset))
         {
-          /* If no font(set) could be loaded, we fallback to "Sans",
+          /* If no font(set) could be loaded, we fallback to "Apple Color
+           * Emoji" for emoji font, fallback to "Sans" for other fonts,
            * which should always work on Mac. We try to adhere to the
            * requested style at first.
            */
@@ -1333,7 +1334,10 @@
           pango_font_description_free (key.desc);
 
           tmp_desc = pango_font_description_copy_static (desc);
-          pango_font_description_set_family_static (tmp_desc, "Sans");
+          if (!strcmp (pango_font_description_get_family (tmp_desc), "emoji"))
+            pango_font_description_set_family_static (tmp_desc, "Apple Color Emoji");
+          else
+            pango_font_description_set_family_static (tmp_desc, "Sans");
 
           pango_core_text_fontset_key_init (&key, ctfontmap, context, tmp_desc,
                                             language);
