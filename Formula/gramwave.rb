class Gramwave < Formula
  desc "Read-only Telegram music player for Linux"
  homepage "https://github.com/mag7ster/gramwave"
  url "https://github.com/mag7ster/gramwave/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "cf8f391dc05babd81265ebfa520ef4dcb0a175e6f061fd81813315b6ae8e15be"
  license "MIT"


  depends_on :linux
  depends_on "cmake" => :build
  depends_on "pkgconf" => :build
  depends_on "rust" => :build
  depends_on "alsa-lib"
  depends_on "glib"
  depends_on "mag7ster/gramwave/gramwave-tdlib"
  depends_on "wayland"

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    ENV["GRAMWAVE_TDLIB_DIR"] = dep("gramwave-tdlib").opt_prefix
    config = ENV["HOMEBREW_GRAMWAVE_TELEGRAM_CONFIG"]
    if config.to_s.empty?
      odie "Set HOMEBREW_GRAMWAVE_TELEGRAM_CONFIG to your Telegram credentials file. " \
           "See https://github.com/mag7ster/gramwave#build-and-run"
    end

    ENV["GRAMWAVE_TELEGRAM_CONFIG"] = config
    staging = buildpath/"cargo-install"
    features = %w[audio webm-emoji telegram vulkan release-branding]
    system "cargo", "install", "--no-default-features", *std_cargo_args(root: staging, features:)
    bin.install staging/"bin/gramwave-dev" => "gramwave"
    (share/"applications").install "assets/gramwave.desktop"
    (share/"icons/hicolor/scalable/apps").install "assets/gramwave.svg"
  end

  test do
    assert_equal "gramwave #{version}", shell_output("#{bin}/gramwave --version").strip
  end
end
