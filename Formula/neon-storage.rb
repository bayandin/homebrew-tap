class NeonStorage < Formula
  desc "Storage components for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon/archive/refs/tags/release-3509.tar.gz"
  sha256 "465e01f00fa60a506c32cb08446c7d1920383f01599219fc38ecbfb2201a85eb"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, ventura:      "988d000830436491cebc2c5ddc83d0e119f37f7582c09a42b267fb3462bc8e67"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "60e597b423956c6d7660fa0cc95c3dc9435b4ffd07a2920ded72c759603bb663"
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
