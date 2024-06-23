class NeonProxy < Formula
  desc "Proxy for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-proxy-5751",
    revision: "5d62c67e75160e967f80fb0eefaca30501b17dbe"
  license "Apache-2.0"
  revision 1
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

  def install
    ENV["BUILD_TAG"] = build.stable? ? "release-proxy-#{version}" : "dev-#{Utils.git_short_head}"
    ENV["GIT_VERSION"] = Utils.git_head

    args = std_cargo_args(root: libexec, path: "proxy") + %w[
      --features testing
    ]
    system "cargo", "install", *args

    (bin/"neon-proxy").write <<~EOS
      #!/bin/bash

      CERTS_DIR="#{var}/neon-proxy/certs"
      for arg in "$@"; do
        case "$arg" in
          "--tls-cert" | "-c" | "--tls-key" | "-k" | "--certs-dir")
            CERTS_DIR=""
            ;;
          *)
            ;;
        esac
      done

      if [ -n "${CERTS_DIR}" ]; then
        exec "#{libexec}/bin/proxy" --certs-dir="${CERTS_DIR}" "$@"
      else
        exec "#{libexec}/bin/proxy" "$@"
      fi
    EOS
  end

  def post_install
    certs_dir = var/"neon-proxy/certs"
    return if (certs_dir/"tls.crt").exist? && (certs_dir/"/tls.key").exist?

    mkdir_p certs_dir
    args = [
      "req",
      "-new",
      "-x509",
      "-days",
      "365",
      "-nodes",
      "-text",
      "-out",
      "#{certs_dir}/tls.crt",
      "-keyout",
      "#{certs_dir}/tls.key",
      "-subj",
      "/CN=*.localtest.me",
      "-addext",
      "subjectAltName = DNS:*.localtest.me",
    ]
    system Formula["openssl@3"].opt_bin/"openssl", *args
  end

  test do
    system bin/"neon-proxy", "--version"
  end
end
