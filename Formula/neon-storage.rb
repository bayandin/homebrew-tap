class NeonStorage < Formula
  desc "Storage components for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-5837",
    revision: "feeb2dc6fa568bc890c7d037cc481836b328ace8"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  livecheck do
    url :head
    regex(/^release-(\d+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_sonoma: "5f7ac0a6068b0c9d24cf1268b0046f3f9d4234a75f79f4093bd5aeb242961553"
    sha256 cellar: :any,                 ventura:      "2abbb78ef807967ba83adb87498b11a42fd87eb7d835ef763a03a65b424e0020"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "047f6ad3b142fca1cd545738f19952f16b2ba0aa47ae6cde1ef9857c56c29ce6"
  end

  depends_on "pkg-config" => :build
  depends_on "rust" => :build
  depends_on "bayandin/tap/neon-postgres"
  depends_on "openssl@3"
  depends_on "protobuf"

  uses_from_macos "llvm" => :build

  on_linux do
    # `storage_controller` got linked with system libpq on Linux.
    # Not sure how to prevent it from doing that, so just depend on it to make audit happy
    depends_on "libpq"
  end

  def binaries
    %w[
      compute_ctl neon_local pagebench pagectl pageserver
      safekeeper storage_broker storage_controller
      storage_scrubber storcon_cli trace wal_craft
    ]
  end

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def install
    ENV["BUILD_TAG"] = build.stable? ? "release-#{version}" : "dev-#{Utils.git_short_head}"
    ENV["GIT_VERSION"] = Utils.git_head
    ENV["POSTGRES_INSTALL_DIR"] = neon_postgres.opt_libexec
    ENV["POSTGRES_DISTRIB_DIR"] = neon_postgres.opt_libexec

    ENV["PQ_LIB_DIR"] = neon_postgres.pg_lib_for("v16") if OS.mac?
    mkdir_p libexec/"storage_controller"
    cp_r "storage_controller/migrations", libexec/"storage_controller/"

    system "cargo", "install", *std_cargo_args(root: libexec, path: "compute_tools")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "control_plane")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "control_plane/storcon_cli")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "libs/postgres_ffi/wal_craft")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "pageserver")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "pageserver/ctl")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "pageserver/pagebench")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "safekeeper")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "storage_broker")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "storage_controller")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "storage_scrubber")
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
