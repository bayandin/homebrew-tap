class TeleportAT16 < Formula
  desc "Modern SSH server for teams managing distributed infrastructure"
  homepage "https://goteleport.com/"
  url "https://github.com/gravitational/teleport/archive/refs/tags/v16.4.9.tar.gz"
  sha256 "3a6ba4dab4f7ea3a34850df1b451a009098299a5f1238d52e74e4f1dd49260cd"
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
    sha256 cellar: :any,                 arm64_sequoia: "8145983669bf26fe91b117e5790aacc363691adf43c9ea65c66aa087a12911d1"
    sha256 cellar: :any,                 arm64_sonoma:  "eaafee8195ebe0c9225cf438544240d04d8311ede771d5dcfcf0832e6019312d"
    sha256 cellar: :any,                 ventura:       "eb339306e284304768eb0a35782700dc52551e7ebc4a23e792e8422b96c78919"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "cddda41dc2e35dc20dabd097e123b740a0fefde80a6186cd175cb6886afb10fd"
  end

  # Use "go" again after https://github.com/gravitational/teleport/commit/e4010172501f0ed18bb260655c83606dfa872fbd
  # is released, likely in a version 17.x.x (or later?):
  depends_on "go@1.22" => :build
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
  # rubocop:enable FormulaAudit/Conflicts, Style/DisableCopsWithinSourceCodeDirective

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
