class NeonProxy < Formula
  desc "Proxy for Neon"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-proxy-7510",
    revision: "3e624581cdc90e51d323154f7acec404eec972c1"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  livecheck do
    url :head
    regex(/^release-proxy-(\d+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "87c85c39aca999eb48b4dcfbdd55c09db650c6c6364edc64905bd017504b4317"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "131e396ed65ec709dd617cd60c9fcae37fabe01698a0e8f7b215e6435d623538"
    sha256 cellar: :any_skip_relocation, ventura:       "e25b5d1d393cb4c778a598ceab0e6c3bba2c127c85c1ec5f7af572962a9bf7f3"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "735246490aae185e8514abb7199061cb2d082f746a187a3a009f50afefa08cfa"
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
