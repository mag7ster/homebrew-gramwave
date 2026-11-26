class Gramwave < Formula
  desc "Read-only Telegram music player for Linux"
  homepage "https://github.com/mag7ster/gramwave"
  url "https://github.com/mag7ster/gramwave/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "abb597a5c631785ba231f0efc4fbd751f02080b5ae20fa485e40ef83ca847626"
  license "MIT"

  bottle do
    root_url "https://raw.githubusercontent.com/mag7ster/homebrew-gramwave/bottle-v0.1.0"
    sha256 cellar: :any, x86_64_linux: "661f93d848368cb44385a64c3c07ba467d69662182fb0ad42d1fe53833c12d67"
  end

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
