class S5cmd < Formula
  desc "Parallel S3 and local filesystem execution tool"
  homepage "https://github.com/peak/s5cmd/"
  url "https://github.com/peak/s5cmd/archive/refs/tags/v2.3.0.tar.gz"
  sha256 "6910763a7320010aa75fe9ef26f622e440c2bd6de41afdbfd64e78c158ca19d4"
  license "MIT"
  head "https://github.com/peak/s5cmd.git", branch: "master"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "5e3e77de5e13d06ffd537acb69b7db5df724b6d3404c136ae90b9c658fac4e14"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "0a5c6d690136ef90234d4794525308525c25f61a732e52107c3dc8e0336f291a"
    sha256 cellar: :any_skip_relocation, ventura:       "a1d6236c39a6e799d21096074320736dbf326151e73c7363bffd314e6131f7f4"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "eb2d4bbd14087e6a971be0e4d80875c929ceb186fa0bf1f849e3d2eb38910af0"
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
