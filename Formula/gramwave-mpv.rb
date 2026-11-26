class GramwaveMpv < Formula
  desc "Audio-focused libmpv build for Gramwave"
  homepage "https://mpv.io/"
  url "https://github.com/mpv-player/mpv/archive/refs/tags/v0.42.0.tar.gz"
  sha256 "bcfebbfa2b65a6d88dc97ea18117831072373e38b5785a2afb874ed4df5070dd"
  license all_of: ["GPL-2.0-or-later", "LGPL-2.1-or-later"]

  keg_only "Gramwave uses a libmpv build with audio output only"
  depends_on :linux
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "alsa-lib"
  depends_on "ffmpeg"
  depends_on "libass"
  depends_on "libplacebo"
  depends_on "pipewire"
  depends_on "pulseaudio"
  depends_on "zlib-ng-compat"

  deny_network_access!

  def install
    system "meson", "setup", "build", *std_meson_args, "--auto-features=disabled",
           "-Dcplayer=false", "-Dlibmpv=true", "-Dbuild-date=false", "-Dgl=disabled", "-Dlua=disabled",
           "-Dalsa=enabled", "-Dpipewire=enabled", "-Dpulse=enabled", "-Dzlib=enabled"
    system "meson", "compile", "-C", "build"
    system "meson", "install", "-C", "build"
  end

  test do
    (testpath/"client.c").write <<~C
      #include <mpv/client.h>
      int main(void) {
        mpv_handle *mpv = mpv_create();
        if (!mpv) return 1;
        int failed = mpv_set_option_string(mpv, "video", "no") < 0 ||
                     mpv_set_option_string(mpv, "ao", "null") < 0 ||
                     mpv_initialize(mpv) < 0;
        mpv_terminate_destroy(mpv);
        return failed;
      }
    C
    system ENV.cc, "client.c", "-I#{include}", "-L#{lib}", "-Wl,-rpath,#{lib}", "-lmpv", "-o", "client"
    system "./client"
  end
end
