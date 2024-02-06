class NeonStorage < Formula
  desc "Storage components for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-4781",
    revision: "b9238059d6feb796dc0a8c1331aeaae8b22cb338"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_sonoma: "e4888f31ceae19a68ec34c3dd3de4e10b2d976455fe07d92834c2adc690f1516"
    sha256 cellar: :any,                 ventura:      "6aca32d9e4b3a0d51a0ce8bb607f9028111fbea45afc6fa5fd6eb55818a8340f"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "00d75ac9aeb3af1eb6b089b6e6c6cca1902e81a9db2fbcc50a7bc617b4c2e829"
  end

  depends_on "pkg-config" => :build
  depends_on "rust" => :build
  depends_on "bayandin/tap/neon-postgres"
  depends_on "openssl@3"
  depends_on "protobuf"

  uses_from_macos "llvm" => :build

  on_linux do
    # `attachment_service` got linked with system libpq on Linux.
    # Not sure how to prevent it from doing that, so just depend on it to make audit happy
    depends_on "libpq"
  end

  def binaries
    %w[
      attachment_service compute_ctl neon_local pagebench
      pagectl pageserver pg_sni_router proxy s3_scrubber
      safekeeper storage_broker trace wal_craft
    ]
  end

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def install
    # A workaround for `FATAL:  postmaster became multithreaded during startup` on macOS >= 14.2
    # See https://www.postgresql.org/message-id/flat/CYMBV0OT7216.JNRUO6R6GH86%40neon.tech
    if OS.mac?
      inreplace "control_plane/src/endpoint.rs", "cmd.args([\"--http-port\", &self.http_address.port().to_string()])",
                                                <<~EOS
                                                  cmd.args(["--http-port", &self.http_address.port().to_string()])
                                                     .env("DYLD_LIBRARY_PATH", "#{Formula["bayandin/tap/curl-without-ipv6"].opt_lib}")
                                                EOS
    end

    ENV["BUILD_TAG"] = build.stable? ? "release-#{version}" : "dev-#{Utils.git_short_head}"
    ENV["GIT_VERSION"] = Utils.git_head
    ENV["POSTGRES_INSTALL_DIR"] = neon_postgres.opt_libexec
    ENV["POSTGRES_DISTRIB_DIR"] = neon_postgres.opt_libexec

    ENV["PQ_LIB_DIR"] = neon_postgres.pg_lib_for("v16") if OS.mac?
    mkdir_p libexec/"control_plane/attachment_service"
    cp_r "control_plane/attachment_service/migrations", libexec/"control_plane/attachment_service/"

    system "cargo", "install", *std_cargo_args(root: libexec, path: "compute_tools")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "control_plane")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "control_plane/attachment_service")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "libs/postgres_ffi/wal_craft")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "pageserver")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "pageserver/ctl")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "pageserver/pagebench")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "proxy")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "s3_scrubber")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "safekeeper")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "storage_broker")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "trace")
  end

  test do
    (binaries - %w[pagebench wal_craft]).each do |file|
      system libexec/"bin"/file, "--version"
    end

    system libexec/"bin/wal_craft", "--help"
    system libexec/"bin/pagebench", "--help"
  end
end
