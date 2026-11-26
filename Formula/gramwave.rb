class Gramwave < Formula
  desc "Read-only Telegram music player for Linux"
  homepage "https://github.com/mag7ster/gramwave"
  url "https://github.com/mag7ster/gramwave/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "809d46cc1ef27c9e3a68190c6cdf5f7891a7da9e5fff3821db11ebfa1053236f"
  license "MIT"
  revision 1

  bottle do
    root_url "https://raw.githubusercontent.com/mag7ster/homebrew-gramwave/bottle-v0.2.0-r1"
    sha256 cellar: :any, x86_64_linux: "8ff5ef7b5f1b9748f05bd413cca244e90ba1ecac552663679c344d632223fc36"
  end

  depends_on :linux
  depends_on "pkgconf" => :build
  depends_on "rust" => :build
  depends_on "ffmpeg"
  depends_on "glib"
  depends_on "mag7ster/gramwave/gramwave-tdlib"
  depends_on "mag7ster/gramwave/gramwave-mpv"
  depends_on "wayland"

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    ENV["GRAMWAVE_TDLIB_DIR"] = dep("gramwave-tdlib").opt_prefix
    ENV["MPV_LIBRARY_DIR"] = dep("gramwave-mpv").opt_lib
    features = %w[mpv telegram vulkan]
    if version.to_s == "0.1.0"
      system "cargo", "install", "--no-default-features", *std_cargo_args(features:)
    else
      config = ENV["HOMEBREW_GRAMWAVE_TELEGRAM_CONFIG"]
      if config.to_s.empty?
        odie "Set HOMEBREW_GRAMWAVE_TELEGRAM_CONFIG to your Telegram credentials file. " \
             "See https://github.com/mag7ster/gramwave#build-and-run"
      end

      ENV["GRAMWAVE_TELEGRAM_CONFIG"] = config
      staging = buildpath/"cargo-install"
      features << "release-branding"
      system "cargo", "install", "--no-default-features", *std_cargo_args(root: staging, features:)
      bin.install staging/"bin/gramwave-dev" => "gramwave"
    end
    (share/"applications").install "assets/gramwave.desktop"
    (share/"icons/hicolor/scalable/apps").install "assets/gramwave.svg"
  end

  test do
    assert_equal "gramwave #{version}", shell_output("#{bin}/gramwave --version").strip
  end
end
