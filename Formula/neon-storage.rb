class NeonStorage < Formula
  desc "Storage components for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon/archive/refs/tags/release-3668.tar.gz"
  sha256 "35020adba0458de9f9d27fd885787ba542a3ad29e165c0cad696d3b3970891be"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "1062a544f1874e8f522ca83a347b2c3142ff3e43178b32c02331e7ed3569dbfe"
    sha256 cellar: :any_skip_relocation, ventura:       "0b50f78211ff86aef847e80d3eac53771f444e04096a4a95faa18be864f6bead"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "e5360f00e053a96db02a05e2be8a19787b06361a2c798a0c1528e7a2637385a4"
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
