class NeonStorage < Formula
  desc "Storage components for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-4642",
    revision: "a1a74eef2c60c283bc038b65b99db2ed0c68f5bb"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "517326369904d300c53ae9d87db49a0341c1fe774d1e82462837772b1facb8c6"
    sha256 cellar: :any_skip_relocation, ventura:       "c74d5bcce6c9fb2aa317be7fe196b9032693ff8d0347ebbc7de88f20d90ce269"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "bbf83a9eba9d7f0721c9f69a7cce0ec47cbd9ce69fbe736ff37621488131dbe0"
  end

  depends_on "bayandin/tap/neon-postgres" => :build
  depends_on "pkg-config" => :build
  depends_on "rust" => :build
  depends_on "openssl@3"
  depends_on "protobuf"

  uses_from_macos "llvm" => :build

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
    ENV["BUILD_TAG"] = build.stable? ? "release-#{version}" : "dev-#{Utils.git_short_head}"
    ENV["GIT_VERSION"] = Utils.git_head

    # A workaround for `FATAL:  postmaster became multithreaded during startup` on macOS >= 14.2
    # See https://www.postgresql.org/message-id/flat/CYMBV0OT7216.JNRUO6R6GH86%40neon.tech
    if OS.mac?
      inreplace "control_plane/src/endpoint.rs", "cmd.args([\"--http-port\", &self.http_address.port().to_string()])",
                                                <<~EOS
                                                  cmd.args(["--http-port", &self.http_address.port().to_string()])
                                                     .env("DYLD_LIBRARY_PATH", "#{Formula["bayandin/tap/curl-without-ipv6"].opt_lib}")
                                                EOS
    end

    with_env(POSTGRES_INSTALL_DIR: neon_postgres.opt_libexec) do
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
  end

  test do
    (binaries - %w[pagebench wal_craft]).each do |file|
      system libexec/"bin"/file, "--version"
    end

    system libexec/"bin/wal_craft", "--help"
    system libexec/"bin/pagebench", "--help"
  end
end
