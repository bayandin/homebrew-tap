class NeonProxy < Formula
  desc "Proxy for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-proxy-6844",
    revision: "0467d88f068d5e59bb620b843b08645075288361"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  livecheck do
    url :head
    regex(/^release-proxy-(\d+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "0ba199157a00f4b9ae7d8c489112298b034cf590b2cca4b6fafe489fed7ad96d"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "251e5d085ebd3f7b9070e65ec3bdd723980e5c1361dcdf80f461bed59b53d46d"
    sha256 cellar: :any_skip_relocation, ventura:       "5522f0bdcc568498f395140e7d6dd2bd47d4a46fa6f04bdb69e62780d01caf53"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "61c6b74875141ac6366f0d87ed9099b746ea42fc3dcbaa3ce9f66c6cb76d0ad9"
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
