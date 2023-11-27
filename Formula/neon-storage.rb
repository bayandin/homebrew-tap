class NeonStorage < Formula
  desc "Storage components for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-4270",
    revision: "27096858dcffef3f13aa545f25f9a736ff231101"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "16150d717e7bb28585495fd8fa63d72641b372276eadf85b430e1a918eabdd5a"
    sha256 cellar: :any_skip_relocation, ventura:       "2cd52bcea58b784578e1af5be38f6948f9267525ece20b586758fdfb1e4c918e"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "87d7ce2c46b2a6c371c864fe6454cef1ec65d6672860d8299ef54aef39acf406"
  end

  depends_on "bayandin/tap/neon-postgres" => :build
  depends_on "pkg-config" => :build
  depends_on "rust" => :build
  depends_on "openssl@3"
  depends_on "protobuf"

  uses_from_macos "llvm" => :build

  def binaries
    %w[
      compute_ctl neon_local pagectl pageserver
      pg_sni_router proxy safekeeper
      storage_broker trace wal_craft
    ]
  end

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def install
    ENV["BUILD_TAG"] = build.stable? ? "release-#{version}" : "dev-#{Utils.git_short_head}"
    ENV["GIT_VERSION"] = Utils.git_head

    with_env(POSTGRES_INSTALL_DIR: neon_postgres.opt_libexec) do
      system "cargo", "install", *std_cargo_args(root: libexec, path: "compute_tools")
      system "cargo", "install", *std_cargo_args(root: libexec, path: "control_plane")
      system "cargo", "install", *std_cargo_args(root: libexec, path: "libs/postgres_ffi/wal_craft")
      system "cargo", "install", *std_cargo_args(root: libexec, path: "pageserver")
      system "cargo", "install", *std_cargo_args(root: libexec, path: "pageserver/ctl")
      system "cargo", "install", *std_cargo_args(root: libexec, path: "proxy")
      system "cargo", "install", *std_cargo_args(root: libexec, path: "safekeeper")
      system "cargo", "install", *std_cargo_args(root: libexec, path: "storage_broker")
      system "cargo", "install", *std_cargo_args(root: libexec, path: "trace")
    end
  end

  test do
    (binaries - %w[wal_craft]).each do |file|
      system libexec/"bin"/file, "--version"
    end

    system libexec/"bin/wal_craft", "--help"
  end
end
