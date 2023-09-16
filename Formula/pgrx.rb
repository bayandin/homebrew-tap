class Pgrx < Formula
  desc "Build Postgres Extensions with Rust"
  homepage "https://github.com/pgcentralfoundation/pgrx"
  url "https://github.com/pgcentralfoundation/pgrx/archive/refs/tags/v0.10.1.tar.gz"
  sha256 "b93b3e75dd7484c14e383ccb7f026d6b6cbec584fdb476c9c4f670a9e745ae50"
  license "MIT"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "cc6a50974b507b996aaae69310f5d9b9dcaf23ae4ebd4b87619bd67dbddd6519"
    sha256 cellar: :any_skip_relocation, ventura:       "0cee43c47e95b11e738647e8dcfbe92e555ca3392657b263a55f89888766d10b"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "6313a3a8e545255d4f312163461124e8d3701a3a16a55148422fb183132a857d"
  end

  depends_on "postgresql@16" => :test
  depends_on "rust"
  depends_on "rustfmt"

  def install
    system "cargo", "install", *std_cargo_args(path: "cargo-pgrx")
  end

  test do
    system "cargo", "pgrx", "init", "--pg16", Formula["postgresql@16"].opt_bin/"pg_config"
    system "cargo", "pgrx", "new", "example"
    cd "example" do
      # Postgres symbols won't be available until runtime
      ENV["RUSTFLAGS"] = "-Clink-arg=-Wl,-undefined,dynamic_lookup"

      system "cargo", "pgrx", "package", "--pg-config", Formula["postgresql@16"].opt_bin/"pg_config",
                                         "--out-dir", testpath/"out"
    end
  end
end
