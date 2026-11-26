class GramwaveTdlib < Formula
  desc "Telegram Database Library for Gramwave"
  homepage "https://core.telegram.org/tdlib"
  url "https://github.com/tdlib/td/archive/6d509061574d684117f74133056aa43df89022fc.tar.gz"
  version "1.8.61"
  sha256 "72ec4d4a0a575a7e836941cc6a7e70c5c770aea4a782739f7c803625b9c04722"
  license "BSL-1.0"
  revision 2

  keg_only "Gramwave requires this TDLib version"
  depends_on :linux
  depends_on "cmake" => :build
  depends_on "gperf" => :build
  depends_on "ninja" => :build
  depends_on "openssl@3"
  depends_on "zlib-ng-compat"

  fails_with :clang

  deny_network_access!

  def install
    system "cmake", "-S", ".", "-B", "build", "-G", "Ninja",
           "-DBUILD_TESTING=OFF", "-DCMAKE_C_COMPILER=#{ENV.cc}", "-DCMAKE_CXX_COMPILER=#{ENV.cxx}",
           "-DOPENSSL_ROOT_DIR=#{dep("openssl@3").opt_prefix}", *std_cmake_args
    system "cmake", "--build", "build", "--target", "tdjson", "--parallel", [ENV.make_jobs, 2].min.to_s
    soname = "libtdjson.so.#{version}"
    lib.install "build/#{soname}"
    lib.install_symlink soname => "libtdjson.so"
  end

  test do
    (testpath/"client.c").write <<~C
      #include <string.h>
      extern int td_create_client_id(void);
      extern const char *td_execute(const char *);
      int main(void) {
        const char *version = td_execute("{\\"@type\\":\\"getOption\\",\\"name\\":\\"version\\"}");
        return !version || !strstr(version, "#{version}") || td_create_client_id() <= 0;
      }
    C
    system ENV.cc, "client.c", "-L#{lib}", "-Wl,-rpath,#{lib}", "-ltdjson", "-o", "client"
    system "./client"
  end
end
