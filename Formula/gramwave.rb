class Gramwave < Formula
  desc "Read-only Telegram music player for Linux"
  homepage "https://github.com/mag7ster/gramwave"
  url "https://github.com/mag7ster/gramwave/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "abb597a5c631785ba231f0efc4fbd751f02080b5ae20fa485e40ef83ca847626"
  license "MIT"

  depends_on :linux
  depends_on "pkgconf" => :build
  depends_on "rust" => :build
  depends_on "ffmpeg"
  depends_on "glib"
  depends_on "mag7ster/gramwave/gramwave-tdlib"
  depends_on "mpv"
  depends_on "wayland"

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    ENV["GRAMWAVE_TDLIB_DIR"] = dep("gramwave-tdlib").opt_prefix
    system "cargo", "install", "--no-default-features", *std_cargo_args(features: "mpv,telegram,vulkan")
    (share/"applications").install "assets/gramwave.desktop"
    (share/"icons/hicolor/scalable/apps").install "assets/gramwave.svg"
  end

  test do
    assert_equal "gramwave #{version}", shell_output("#{bin}/gramwave --version").strip
  end
end
