# The formula is a copy of homebrew/core/curl with disabled IPv6 support.

class CurlWithoutIpv6 < Formula
  desc "Get a file from an HTTP, HTTPS or FTP server"
  homepage "https://curl.se"
  url "https://curl.se/download/curl-8.9.0.tar.bz2"
  sha256 "1cb4c3657bd092b8c8e586afe87679c0aaa3d761af2aebabd6effd553e57936c"
  license "curl"

  livecheck do
    url "https://curl.se/download/"
    regex(/href=.*?curl[._-]v?(.*?)\.t/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_sonoma: "0d577ea83183fa63972e918fb0e9831f367278a99ee665c9577b6375d189b850"
    sha256 cellar: :any,                 ventura:      "9299471654228100e0450d9e44424eece5875e354e5b1ba91b299cb74caf0b46"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "460d1016006ad123d452bf2bea892f1315057af286b6ebadf46368cb98d6330e"
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
