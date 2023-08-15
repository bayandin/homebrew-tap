class NeonStorage < Formula
  desc "Storage components for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon/archive/refs/tags/release-3710.tar.gz"
  sha256 "08c265d57a682cb7bd341efe7fd79065b0bdb5a797d731fe7bc672b18f2e520e"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "1cb566893a9f5308b204a36c50de217f9587c2c3bf395d0b0b4e4a15fd02b1e9"
    sha256 cellar: :any_skip_relocation, ventura:       "fcedc8f4ffb4b748430fb7cda52957bec8310b8733e72746e43e182a6539582d"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "9c154cd26a0f720d20c2c1db0d2b815da0dd2cb7a4208a7ce742990ca5a4f31c"
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
