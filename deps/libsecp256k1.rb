# modified from public source available at https://github.com/cuber/homebrew-libsecp256k1

class Libsecp256k1 < Formula
  desc "Optimized C library for EC operations on curve secp256k1 "
  homepage "https://github.com/bitcoin/secp256k1"
  url "https://github.com/bitcoin/secp256k1.git"
  version "0.1"

  option :universal
  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "gmp" => :optional

  def install
    if build.universal?
      ENV.universal_binary
    end
    system "./autogen.sh"
    system "./configure", "--prefix=#{prefix}", "--enable-module-ecdh", "--enable-module-recovery", "--enable-experimental"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <secp256k1.h>
      int main()
      {
        secp256k1_context *ctx =
          secp256k1_context_create(SECP256K1_CONTEXT_VERIFY |
                                   SECP256K1_CONTEXT_SIGN);
        if (ctx) {
          secp256k1_context_destroy(ctx);
          return 0;
        }
        return 1;
      }
    EOS
    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-lsecp256k1", "-o", "test"
    system "./test"
  end
end
