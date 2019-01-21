class Cairo < Formula
  desc "Vector graphics library with cross-device output support"
  homepage "https://cairographics.org/"
  url "https://cairographics.org/releases/cairo-1.16.0.tar.xz"
  sha256 "5e7b29b3f113ef870d1e3ecf8adf21f923396401604bda16d44be45e66052331"
  revision 1

  bottle do
    sha256 "204d0a3df9ebebef6f553b4a583351f14b84ca8682537941f2c04ba971999444" => :mojave
    sha256 "f518c9e6cd207647eedff70720fc99a85eaf143da866f4e679ffb0b6c6c50098" => :high_sierra
    sha256 "1b0421e0159c06862b742e7868dbef23985afc2f1e282c4d985ff13725995a6d" => :sierra
  end

  head do
    url "https://anongit.freedesktop.org/git/cairo", :using => :git
    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  depends_on "pkg-config" => :build
  depends_on "fontconfig"
  depends_on "freetype"
  depends_on "glib"
  depends_on "libpng"
  depends_on "pixman"

  patch :DATA

  def install
    if build.head?
      ENV["NOCONFIGURE"] = "1"
      system "./autogen.sh"
    end

    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--enable-gobject=yes",
                          "--enable-svg=yes",
                          "--enable-tee=yes",
                          "--enable-quartz-image",
                          "--enable-xcb=no",
                          "--enable-xlib=no",
                          "--enable-xlib-xrender=no"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <cairo.h>

      int main(int argc, char *argv[]) {

        cairo_surface_t *surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 600, 400);
        cairo_t *context = cairo_create(surface);

        return 0;
      }
    EOS
    fontconfig = Formula["fontconfig"]
    freetype = Formula["freetype"]
    gettext = Formula["gettext"]
    glib = Formula["glib"]
    libpng = Formula["libpng"]
    pixman = Formula["pixman"]
    flags = %W[
      -I#{fontconfig.opt_include}
      -I#{freetype.opt_include}/freetype2
      -I#{gettext.opt_include}
      -I#{glib.opt_include}/glib-2.0
      -I#{glib.opt_lib}/glib-2.0/include
      -I#{include}/cairo
      -I#{libpng.opt_include}/libpng16
      -I#{pixman.opt_include}/pixman-1
      -L#{lib}
      -lcairo
    ]
    system ENV.cc, "test.c", "-o", "test", *flags
    system "./test"
  end
end

__END__

Add color emoji support for macOS.
Render color glyphs for "Apple Color Emoji" font.

diff -u -r cairo-1.16.0-origin/src/cairo-quartz-font.c cairo-1.16.0/src/cairo-quartz-font.c
--- cairo-1.16.0-origin/src/cairo-quartz-font.c	2018-08-16 18:10:53.000000000 -0700
+++ cairo-1.16.0/src/cairo-quartz-font.c	2019-01-18 14:56:16.000000000 -0800
@@ -150,6 +150,8 @@
     CGContextGetAllowsFontSmoothingPtr = dlsym(RTLD_DEFAULT, "CGContextGetAllowsFontSmoothing");
     CGContextSetAllowsFontSmoothingPtr = dlsym(RTLD_DEFAULT, "CGContextSetAllowsFontSmoothing");
 
+    CTFontCreateWithGraphicsFontPtr = dlsym(RTLD_DEFAULT, "CTFontCreateWithGraphicsFont");
+
     FMGetATSFontRefFromFontPtr = dlsym(RTLD_DEFAULT, "FMGetATSFontRefFromFont");
 
     if ((CGFontCreateWithFontNamePtr || CGFontCreateWithNamePtr) &&
@@ -175,6 +177,7 @@
     cairo_font_face_t base;
 
     CGFontRef cgFont;
+    CTFontRef ctFont;
 };
 
 /*
@@ -259,6 +262,10 @@
 {
     cairo_quartz_font_face_t *font_face = (cairo_quartz_font_face_t*) abstract_face;
 
+    if (font_face->ctFont) {
+        CFRelease (font_face->ctFont);
+    }
+
     CGFontRelease (font_face->cgFont);
     return TRUE;
 }
@@ -355,6 +362,14 @@
     _cairo_quartz_font_face_scaled_font_create
 };
 
+static bool CTFontIsAppleColorEmoji (CTFontRef font)
+{
+    CFStringRef name = CTFontCopyFamilyName (font);
+    CFComparisonResult ret = CFStringCompare (name, CFSTR("Apple Color Emoji"), 0);
+    CFRelease(name);
+    return ret == kCFCompareEqualTo;
+}
+
 /**
  * cairo_quartz_font_face_create_for_cgfont:
  * @font: a #CGFontRef obtained through a method external to cairo.
@@ -384,6 +399,12 @@
 
     font_face->cgFont = CGFontRetain (font);
 
+    if (CTFontCreateWithGraphicsFontPtr) {
+        font_face->ctFont = CTFontCreateWithGraphicsFontPtr (font, 1.0, NULL, NULL);
+    } else {
+        font_face->ctFont = NULL;
+    }
+
     _cairo_font_face_init (&font_face->base, &_cairo_quartz_font_face_backend);
 
     return &font_face->base;
@@ -610,6 +631,8 @@
     cairo_image_surface_t *surface = NULL;
 
     CGGlyph glyph = _cairo_quartz_scaled_glyph_index (scaled_glyph);
+  
+    cairo_bool_t is_color_glyph = CTFontIsAppleColorEmoji (font_face->ctFont);
 
     int advance;
     CGRect bbox;
@@ -679,28 +702,40 @@
 
     //fprintf (stderr, "glyphRect[n]: %f %f %f %f\n", glyphRect.origin.x, glyphRect.origin.y, glyphRect.size.width, glyphRect.size.height);
 
-    surface = (cairo_image_surface_t*) cairo_image_surface_create (CAIRO_FORMAT_A8, width, height);
+    if (is_color_glyph)
+	surface = (cairo_image_surface_t*) cairo_image_surface_create (CAIRO_FORMAT_ARGB32, width, height);
+    else
+	surface = (cairo_image_surface_t*) cairo_image_surface_create (CAIRO_FORMAT_A8, width, height);
+
     if (surface->base.status)
 	return surface->base.status;
 
     if (surface->width != 0 && surface->height != 0) {
-	cgContext = CGBitmapContextCreate (surface->data,
-					   surface->width,
-					   surface->height,
-					   8,
-					   surface->stride,
-					   NULL,
-					   kCGImageAlphaOnly);
+	if (is_color_glyph) {
+	    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
+	    cgContext = CGBitmapContextCreate (surface->data,
+					       surface->width,
+					       surface->height,
+					       8,
+					       surface->stride,
+					       colorSpace,
+					       kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
+	    CGColorSpaceRelease (colorSpace);
+	} else {
+	    cgContext = CGBitmapContextCreate (surface->data,
+					       surface->width,
+					       surface->height,
+					       8,
+					       surface->stride,
+					       NULL,
+					       kCGImageAlphaOnly);
+	}
 
 	if (cgContext == NULL) {
 	    cairo_surface_destroy (&surface->base);
 	    return _cairo_error (CAIRO_STATUS_NO_MEMORY);
 	}
 
-	CGContextSetFont (cgContext, font_face->cgFont);
-	CGContextSetFontSize (cgContext, 1.0);
-	CGContextSetTextMatrix (cgContext, textMatrix);
-
 	switch (font->base.options.antialias) {
 	case CAIRO_ANTIALIAS_SUBPIXEL:
 	case CAIRO_ANTIALIAS_BEST:
@@ -726,8 +761,29 @@
 	}
 
 	CGContextSetAlpha (cgContext, 1.0);
-	CGContextShowGlyphsAtPoint (cgContext, - glyphOrigin.x, - glyphOrigin.y, &glyph, 1);
 
+	if (is_color_glyph) {
+	    CGContextSaveGState (cgContext);
+	    // CGContextSetTextMatrix does not work with color glyphs, so we use the
+	    // CTM instead. This means we must translate the CTM as well, to set the
+	    // glyph position, instead of using CGContextSetTextPosition.
+	    CGContextTranslateCTM (cgContext, - glyphOrigin.x, - glyphOrigin.y);
+	    CGContextConcatCTM (cgContext, textMatrix);
+	    {
+		// XXX(suyuan): Workaround bug that Apple Color Emoji glyph font rendered
+		//   size doesn't match expectation.
+		CGAffineTransform t = CGAffineTransformMake(0.75, 0, 0, 0.75, 0.05, 0.1);
+		CGContextConcatCTM (cgContext, t);
+	    }
+	    CTFontDrawGlyphs (font_face->ctFont, &glyph, &CGPointZero, 1, cgContext);
+	    CGContextRestoreGState (cgContext);
+	} else {
+	    CGContextSetFont (cgContext, font_face->cgFont);
+	    CGContextSetFontSize (cgContext, 1.0);
+	    CGContextSetTextMatrix (cgContext, textMatrix);
+	    CGContextShowGlyphsAtPoint (cgContext, - glyphOrigin.x, - glyphOrigin.y, &glyph, 1);
+	}
+  
 	CGContextRelease (cgContext);
     }
 
@@ -737,6 +793,9 @@
 
     _cairo_scaled_glyph_set_surface (scaled_glyph, &font->base, surface);
 
+    if (is_color_glyph)
+        _cairo_scaled_glyph_set_color_surface (scaled_glyph, &font->base, surface);
+
     return status;
 }
 
@@ -808,6 +867,14 @@
     return CAIRO_STATUS_SUCCESS;
 }
 
+static cairo_bool_t
+_cairo_quartz_has_color_glyphs (void *scaled)
+{
+    cairo_quartz_font_face_t *font_face =
+        _cairo_quartz_scaled_to_face((cairo_scaled_font_t *)scaled);
+    return CTFontIsAppleColorEmoji (font_face->ctFont);
+}
+
 static const cairo_scaled_font_backend_t _cairo_quartz_scaled_font_backend = {
     CAIRO_FONT_TYPE_QUARTZ,
     _cairo_quartz_scaled_font_fini,
@@ -816,6 +883,10 @@
     _cairo_quartz_ucs4_to_index,
     _cairo_quartz_load_truetype_table,
     NULL, /* map_glyphs_to_unicode */
+    NULL, /* is_synthetic */
+    NULL, /* index_to_glyph_name */
+    NULL, /* load_type1_data */
+    _cairo_quartz_has_color_glyphs,
 };
 
 /*
