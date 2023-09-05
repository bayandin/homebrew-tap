class NeonStorage < Formula
  desc "Storage components for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-3836",
    revision: "07d7874bc88cc83a8b57c8d9508674277008a623"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "c0f6f6487ddcdefaecfd999de95f626d6083bf55af668c6e657f754bc25b4f10"
    sha256 cellar: :any_skip_relocation, ventura:       "63eeb1de9ac3be8b0ac564e319e2775f0c644aafd72d67133665b744bedb7385"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "7f6500f41d41d486502f92e490dfdd37387195405423d65dd1c99f1360f52244"
  end

  depends_on "bayandin/tap/neon-postgres" => :build
  depends_on "rust" => :build
  depends_on "openssl@3"
  depends_on "protobuf"

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
    ENV["BUILD_TAG"] = "release-#{version}"
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
