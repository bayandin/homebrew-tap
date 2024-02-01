class NeonStorage < Formula
  desc "Storage components for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-4713",
    revision: "1ec3e39d4e777d53d78eea8eba7d21f37942b000"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_sonoma: "294b042d3909ccabb8f3517118eb9f38b18835b04fd1fbba936ae1ce723d04b1"
    sha256 cellar: :any,                 ventura:      "ca386f9f6dd763eaea8b16ea8cede31b213211cd26f5d888e6fed302b344aed6"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "71c9b89a530ed18103c672d350f46c2a34ae6b2bd8a99af5af217f96fca7fa02"
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
