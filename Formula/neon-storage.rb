class NeonStorage < Formula
  desc "Storage components for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-6548",
    revision: "b5d41eaff48a3d4435a126c8e3ca9910dd785d7b"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  livecheck do
    url :head
    regex(/^release-(\d+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_sonoma: "8c9093f22f486099a28def9d641aac166b1cd23a8297f52c4fb6520312a82891"
    sha256 cellar: :any,                 ventura:      "9a8fbf5a084c562b036ca247ca4cbbbc0a5d242754b7dd0f501c3eccea0142e1"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "e11faa648098ece352aa4efbb481a7fb24d9a6996a81c8100cee612ca9edf881"
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
      storage_scrubber storcon_cli wal_craft
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
  end

  test do
    (binaries - %w[pagebench wal_craft]).each do |file|
      system libexec/"bin"/file, "--version"
    end

    system libexec/"bin/wal_craft", "--help"
    system libexec/"bin/pagebench", "--help"
  end
end
