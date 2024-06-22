class NeonProxy < Formula
  desc "Proxy for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-proxy-5751",
    revision: "5d62c67e75160e967f80fb0eefaca30501b17dbe"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  livecheck do
    url :head
    regex(/^release-proxy-(\d+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "a4d65a3ee777d80f260426be8fa3db1ff48569b4a4d42735e1fe5d3618a2a6ea"
    sha256 cellar: :any_skip_relocation, ventura:      "56012aa76f791b78ac52be9438b9103f72b7a0cbd1fed645ce19c5cdf9fc8dc3"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "03c41e63a14f2c44678a2a48d646477444ebc858eddce88f3859338b9fcce256"
  end

  depends_on "rust" => :build
  depends_on "openssl@3"

  uses_from_macos "llvm" => :build

  def binaries
    %w[
      pg_sni_router
      proxy
    ]
  end

  def install
    ENV["BUILD_TAG"] = build.stable? ? "release-proxy-#{version}" : "dev-#{Utils.git_short_head}"
    ENV["GIT_VERSION"] = Utils.git_head

    system "cargo", "install", *std_cargo_args(root: libexec, path: "proxy")
    bin.install_symlink libexec/"bin/pg_sni_router" => "neon-pg-sni-router"
    bin.install_symlink libexec/"bin/proxy" => "neon-proxy"
  end

  test do
    binaries.each do |file|
      system libexec/"bin"/file, "--version"
    end
  end
end
