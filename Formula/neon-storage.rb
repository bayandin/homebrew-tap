class NeonStorage < Formula
  desc "Storage components for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon/archive/refs/tags/release-3634.tar.gz"
  sha256 "7fecc9e07f391833e25aa6d2817c9ed0799393a0268669d44f4db2e11949f3cb"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "aebe43b4762bcadfe86b8d212f73400f9b3065e08b1ba758513d1c70f994bef1"
    sha256 cellar: :any_skip_relocation, ventura:       "134bb92ce15505e24a567e34426a48ead2b7f9c8fbd9c93927ef516cb5e3d5f6"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "0b49ad2c686bb550c7dd96215155a09bbd07c759eb2f521ef23bbddb3c8cd102"
  end

  depends_on "bayandin/tap/neon-postgres" => :build
  depends_on "rust" => :build
  depends_on "openssl@3"
  depends_on "protobuf"

  def pg_versions
    %w[v14 v15]
  end

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
    build_tag = "release-#{version}"
    ENV["BUILD_TAG"] = build_tag

    cmd = %w[git ls-remote --refs --tags https://github.com/neondatabase/neon.git]
    git_tags = Utils.safe_popen_read(*cmd)
    git_rev = git_tags.split("\n").find { |l| l =~ %r{refs/tags/#{build_tag}$} }&.split("\t")&.first

    odie "Cannot find git revision for #{version} from #{git_tags}" if git_rev.nil?
    ENV["GIT_VERSION"] = git_rev

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
