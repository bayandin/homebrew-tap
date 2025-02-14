class TeleportAT16 < Formula
  desc "Modern SSH server for teams managing distributed infrastructure"
  homepage "https://goteleport.com/"
  url "https://github.com/gravitational/teleport/archive/refs/tags/v16.4.16.tar.gz"
  sha256 "7b61ce5295a2eb9b254a8c326e41746f98670b1684392370fe5de46b38aec0a0"
  license all_of: ["AGPL-3.0-or-later", "Apache-2.0"]
  head "https://github.com/gravitational/teleport.git", branch: "master"

  # As of writing, two major versions of `teleport` are being maintained
  # side by side and the "latest" release can point to an older major version,
  # so we can't use the `GithubLatest` strategy. We use the `GithubReleases`
  # strategy instead of `Git` because there is often a notable gap (days)
  # between when a version is tagged and released.
  livecheck do
    url :stable
    regex(/^v?(16(?:\.\d+)+)$/i)
    strategy :github_releases
  end

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_sequoia: "80b2a7b3f30a74428eca8c525eb3bfc37f2fc1f118f9a17cd18e6f2ad4dca71a"
    sha256 cellar: :any,                 arm64_sonoma:  "4bda254c1613b8a06b3529cffc2ff57b30012211748ba4184fd8fd151029c6a2"
    sha256 cellar: :any,                 ventura:       "4d6c819b30ee10d4599367714f6950cfbd94a074058b7c56ab2bc129cdfc17b9"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "e0d71c459a7490000a4a54fb0f2762f6193b44aad7dfa0c82c69054343cd6a11"
  end

  depends_on "go" => :build
  depends_on "pkg-config" => :build
  depends_on "pnpm" => :build
  depends_on "rust" => :build
  # TODO: try to remove rustup dependancy, see https://github.com/Homebrew/homebrew-core/pull/191633#discussion_r1774378671
  depends_on "rustup" => :build
  depends_on "wasm-pack" => :build
  depends_on "libfido2"
  depends_on "node"
  depends_on "openssl@3"

  uses_from_macos "curl" => :test
  uses_from_macos "netcat" => :test
  uses_from_macos "zip"

  # FormulaAudit/Conflicts: Versioned formulae should not use conflicts_with. Use keg_only :versioned_formula instead.
  # rubocop:disable FormulaAudit/Conflicts, Style/DisableCopsWithinSourceCodeDirective
  conflicts_with "etsh", because: "both install `tsh` binaries"
  conflicts_with "tctl", because: "both install `tctl` binaries"
  conflicts_with "teleport", because: "both install the same binaries"
  # rubocop:enable FormulaAudit/Conflicts, Style/DisableCopsWithinSourceCodeDirective

  # disable `wasm-opt` for ironrdp pkg release build, upstream pr ref, https://github.com/gravitational/teleport/pull/50178
  patch do
    url "https://github.com/gravitational/teleport/commit/994890fb05360b166afd981312345a4cf01bc422.patch?full_index=1"
    sha256 "9d60180ff69a8a8985773d3b2a107ab910b22040e4cbf6afed11bd2b64fc6996"
  end

  def install
    ENV.prepend_path "PATH", Formula["rustup"].bin
    system "rustup", "default", "stable"
    system "rustup", "set", "profile", "minimal"

    ENV.deparallelize { system "make", "full", "FIDO2=dynamic" }
    bin.install Dir["build/*"]
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/teleport version")
    assert_match version.to_s, shell_output("#{bin}/tsh version")
    assert_match version.to_s, shell_output("#{bin}/tctl version")

    mkdir testpath/"data"
    (testpath/"config.yml").write <<~EOS
      version: v2
      teleport:
        nodename: testhost
        data_dir: #{testpath}/data
        log:
          output: stderr
          severity: WARN
    EOS

    fork do
      exec "#{bin}/teleport start --roles=proxy,node,auth --config=#{testpath}/config.yml"
    end

    sleep 10
    system "curl", "--insecure", "https://localhost:3080"

    status = shell_output("#{bin}/tctl --config=#{testpath}/config.yml status")
    assert_match(/Cluster\s*testhost/, status)
    assert_match(/Version\s*#{version}/, status)
  end
end
