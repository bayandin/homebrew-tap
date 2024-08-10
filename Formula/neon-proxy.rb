class NeonProxy < Formula
  desc "Proxy for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-proxy-6107",
    revision: "73935ea3a2cfcd0ee0dc0f6f07fed1bcbaefbf71"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  livecheck do
    url :head
    regex(/^release-proxy-(\d+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "aebaaa78696c4c25aa9bdf4c37df94ae6cae80feb54a4d7029b1d0af0baded6a"
    sha256 cellar: :any_skip_relocation, ventura:      "79aa24161378c2b0228074be2bb3f5e37c23c9112074714d417d8d471068d5c6"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "eed326140635362c699e636ee3f836c6c6e6b5ac0b2ed69ad675d40aaad6305d"
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
