class NeonStorage < Formula
  desc "Storage components for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-8467",
    revision: "eb70d7a55c7d2562b7d3bcbcd4dc0ac501ec9cff"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  livecheck do
    url :head
    regex(/^release-(\d+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "655108f9385ca41ef47054c6c8f0183563d62a34b7c8a6e7c731cfea56e088e3"
    sha256 cellar: :any_skip_relocation, ventura:       "606d9be5a2b9b1f547efa8e76ef2a59426378494c3934c4ed1f6c3763133d8d3"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "b9ba74c01b6e33e479ac878bc93f000a799579ed96b15366ca47165e5dd1bfb6"
  end

  depends_on "pkg-config" => :build
  depends_on "rust" => :build
  depends_on "bayandin/tap/neon-postgres"
  depends_on "openssl@3"
  depends_on "protobuf"

  uses_from_macos "llvm" => :build

  def binaries
    %w[
      compute_ctl endpoint_storage neon_local pagectl
      pageserver safekeeper storage_broker storage_controller
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

    mkdir_p libexec/"storage_controller"
    cp_r "storage_controller/migrations", libexec/"storage_controller/"

    system "cargo", "install", *std_cargo_args(root: libexec, path: "compute_tools")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "control_plane")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "control_plane/storcon_cli")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "libs/postgres_ffi/wal_craft")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "endpoint_storage")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "pageserver")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "pageserver/ctl")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "pageserver/pagebench")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "safekeeper")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "storage_broker")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "storage_controller")
    system "cargo", "install", *std_cargo_args(root: libexec, path: "storage_scrubber")
  end

  test do
    (binaries - %w[compute_ctl endpoint_storage pagebench wal_craft]).each do |file|
      system libexec/"bin"/file, "--version"
    end

    system libexec/"bin/compute_ctl", "--help"
    system libexec/"bin/pagebench", "--help"
    system libexec/"bin/wal_craft", "--help"
  end
end
