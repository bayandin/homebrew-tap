class NeonStorage < Formula
  desc "Storage components for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon/archive/refs/tags/release-3568.tar.gz"
  sha256 "bb314a6ebbe05f5d7204990a9aa32a33f924bdfde7456943a733a8765661dac8"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "e5b5dce151de32af18f0ced14e5fceed0ed0ecc7a3a4c50076f5316e3c835b0f"
    sha256 cellar: :any_skip_relocation, ventura:       "b10328be92d67833ea0354272bd1d8f4b3304b58e0e09cdd2ddfcf83642e520f"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "08007ffe209ff4c2e1acd7c8cb6dc21eb2bf4a5f2bd8d42ae59cbbdbedb32df9"
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
