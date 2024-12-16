class S5cmd < Formula
  desc "Parallel S3 and local filesystem execution tool"
  homepage "https://github.com/peak/s5cmd/"
  url "https://github.com/peak/s5cmd/archive/refs/tags/v2.3.0.tar.gz"
  sha256 "6910763a7320010aa75fe9ef26f622e440c2bd6de41afdbfd64e78c158ca19d4"
  license "MIT"
  head "https://github.com/peak/s5cmd.git", branch: "master"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "d1a30c68927bfd34edf279273e513ec8a94d9506762b415bfe271115c4e94c3f"
    sha256 cellar: :any_skip_relocation, ventura:      "41395b6466580317f8b68169d608efe5c042254a6dc9bef4b4dcf924f0465ecb"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "ecd599d1092cc080b545b855945764abcce79b207f27d94899171ba32747d646"
  end

  depends_on "go" => :build

  def install
    ldflags = %W[
      -s -w
      -X=github.com/peak/s5cmd/v2/version.Version=#{version}
      -X=github.com/peak/s5cmd/v2/version.GitCommit=#{tap.user}
    ]
    system "go", "build", *std_go_args(ldflags:)
    generate_completions_from_executable(bin/"s5cmd", "--install-completion")
  end

  test do
    assert_match "no valid providers in chain", shell_output("#{bin}/s5cmd --retry-count 0 ls s3://brewtest 2>&1", 1)
    assert_match version.to_s, shell_output("#{bin}/s5cmd version")
  end
end
