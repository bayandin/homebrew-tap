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
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "5e096e2c3a230887bf484933f064fc6b9439747f272195cb4591044b48840697"
    sha256 cellar: :any_skip_relocation, ventura:      "483fd919778c4d80ee72acec1e326cb40e0bf7eb6a2f4aac67003144eb22459e"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "04a2e46df785ae22a59c084fd648a356d7158efc055ce1c9c2f1492cf27a7ca0"
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
