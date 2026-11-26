class GramwaveTdlib < Formula
  desc "Telegram Database Library for Gramwave"
  homepage "https://core.telegram.org/tdlib"

  on_intel do
    url "https://github.com/FedericoBruzzone/tdlib-rs/releases/download/v1.4.0/tdlib-1.8.61-linux-x86_64.zip"
    sha256 "997069633f54306ada33776d2c4a530017d2e7325a22e0f12701d52438c37383"
  end

  on_arm do
    url "https://github.com/FedericoBruzzone/tdlib-rs/releases/download/v1.4.0/tdlib-1.8.61-linux-aarch64.zip"
    sha256 "1c9ef54dd34ca5a4053e22853aad763eda80b4188e5a2b22beaa1fa715efbc0a"
  end

  version "1.8.61"
  license "BSL-1.0"
  revision 1

  keg_only "Gramwave requires this TDLib version"
  depends_on :linux
  depends_on "patchelf" => :build
  depends_on "llvm"
  depends_on "openssl@3"
  depends_on "zlib-ng-compat"

  deny_network_access!

  def install
    soname = "libtdjson.so.#{version}"
    lib.install "lib/#{soname}"
    lib.install_symlink soname => "libtdjson.so"

    rpath = %w[llvm openssl@3 zlib-ng-compat].map { |name| dep(name).opt_lib }.join(":")
    system "patchelf", "--set-rpath", rpath, lib/soname
  end

  test do
    (testpath/"client.c").write <<~C
      extern int td_create_client_id(void);
      int main(void) { return td_create_client_id() > 0 ? 0 : 1; }
    C
    system ENV.cc, "client.c", "-L#{lib}", "-Wl,-rpath,#{lib}", "-ltdjson", "-o", "client"
    system "./client"
  end
end
