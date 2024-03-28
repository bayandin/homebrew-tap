class NeonProxy < Formula
  desc "Proxy for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-proxy-5201",
    revision: "2a88889f44d1294d5b70daa8732ba2448c84b5e9"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  livecheck do
    url :head
    regex(/^release-proxy-(\d+)$/i)
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
