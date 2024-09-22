class NeonProxy < Formula
  desc "Proxy for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-proxy-6375",
    revision: "9c23333cb38fb09fe8b3bf3088cbf0aad720a26e"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  livecheck do
    url :head
    regex(/^release-proxy-(\d+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "b8ac7148eb486c934c461f5d4d8ac2ad8bc7696b75f483d76b128d90bca8af9e"
    sha256 cellar: :any_skip_relocation, ventura:      "c53dd5c88913ad085335aa5010e314f66aeef2f24fe1057799a6533ebdaf8bcf"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "ec16daf6c84fba964196fd3ae234ffaf54bc138f9eab2e70522db52798c51c7b"
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
