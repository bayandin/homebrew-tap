# The formula is a copy of homebrew/core/curl with disabled IPv6 support.

class CurlWithoutIpv6 < Formula
  desc "Get a file from an HTTP, HTTPS or FTP server"
  homepage "https://curl.se"
  url "https://curl.se/download/curl-8.10.1.tar.bz2"
  sha256 "3763cd97aae41dcf41950d23e87ae23b2edb2ce3a5b0cf678af058c391b6ae31"
  license "curl"

  livecheck do
    url "https://curl.se/download/"
    regex(/href=.*?curl[._-]v?(.*?)\.t/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_sonoma: "8bf1e543617322e4d3de37d34eda5afe91c2e2ea1ae9ab347d89e6612cbb851a"
    sha256 cellar: :any,                 ventura:      "18de1516f872012ebc9da9baf5ed549a917ae335eef244f40b5ed96912c35e75"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "78955986baefefd2b15338115096dba0d1995616794d174827c32aebd3a7018a"
  end

  head do
    url "https://github.com/curl/curl.git", branch: "master"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  keg_only "it shouldn't be used as a general-purpose curl replacement"

  depends_on "pkg-config" => :build
  depends_on "brotli"
  depends_on "libidn2"
  depends_on "libnghttp2"
  depends_on "libssh2"
  depends_on "openldap"
  depends_on "openssl@3"
  depends_on "rtmpdump"
  depends_on "zstd"

  uses_from_macos "krb5"
  uses_from_macos "zlib"

  def install
    system "./buildconf" if build.head?

    args = %W[
      --disable-debug
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
      --with-ssl=#{Formula["openssl@3"].opt_prefix}
      --without-ca-bundle
      --without-ca-path
      --with-ca-fallback
      --with-secure-transport
      --with-default-ssl-backend=openssl
      --with-libidn2
      --with-librtmp
      --with-libssh2
      --without-libpsl
    ]

    # Since macOS 14.2, if Postgres has a library in `shared_preload_libraries`
    # that's linked with curl it fails with the error:
    #   FATAL:  postmaster became multithreaded during startup
    #
    # Disabling IPv6 support in curl a possible workaround for the issue
    #
    # Ref https://www.postgresql.org/message-id/flat/CYMBV0OT7216.JNRUO6R6GH86%40neon.tech
    args << "--disable-ipv6"

    args << if OS.mac?
      "--with-gssapi"
    else
      "--with-gssapi=#{Formula["krb5"].opt_prefix}"
    end

    system "./configure", *args
    system "make", "install"
    system "make", "install", "-C", "scripts"
    libexec.install "scripts/mk-ca-bundle.pl"
  end

  test do
    # Fetch the curl tarball and see that the checksum matches.
    # This requires a network connection, but so does Homebrew in general.
    filename = (testpath/"test.tar.gz")
    system "#{bin}/curl", "-L", stable.url, "-o", filename
    filename.verify_checksum stable.checksum

    system libexec/"mk-ca-bundle.pl", "test.pem"
    assert_predicate testpath/"test.pem", :exist?
    assert_predicate testpath/"certdata.txt", :exist?

    refute_includes shell_output("#{bin}/curl -V"), "IPv6"
  end
end
