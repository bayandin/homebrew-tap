class S5cmd < Formula
  desc "Parallel S3 and local filesystem execution tool"
  homepage "https://github.com/peak/s5cmd/"
  url "https://github.com/peak/s5cmd/archive/refs/tags/v2.2.2.tar.gz"
  sha256 "6f96a09a13198b84a23b7b7ff0b93f947434a185093284e13d05c0e864907f48"
  license "MIT"
  head "https://github.com/peak/s5cmd.git", branch: "master"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "7708aec8ff8297789970797998a29688dd491e73b7c1bd8c0e09ac4d6f6f00f1"
    sha256 cellar: :any_skip_relocation, ventura:      "90c918923ab13f2b1116c7ba39f73887b2758103dde90a16fa51f4b382e618ec"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "2a13f226103c575ad091b97ee3f9d82dfeb56461d0385dd03b1f009dfd1f3ca6"
  end

  depends_on "go" => :build

  def install
    ldflags = %W[
      -s -w
      -X=github.com/peak/s5cmd/v2/version.Version=#{version}
      -X=github.com/peak/s5cmd/v2/version.GitCommit=#{tap.user}
    ]
    system "go", "build", *std_go_args(ldflags:)
  end

  test do
    assert_match "no valid providers in chain", shell_output("#{bin}/s5cmd --retry-count 0 ls s3://brewtest 2>&1", 1)
    assert_match version.to_s, shell_output("#{bin}/s5cmd version")
  end
end
