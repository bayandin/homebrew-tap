class Pgrx < Formula
  desc "Build Postgres Extensions with Rust"
  homepage "https://github.com/pgcentralfoundation/pgrx"
  url "https://github.com/pgcentralfoundation/pgrx/archive/refs/tags/v0.10.1.tar.gz"
  sha256 "b93b3e75dd7484c14e383ccb7f026d6b6cbec584fdb476c9c4f670a9e745ae50"
  license "MIT"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "5ce73c7d3cf042b2ed2887b6b84247da2ad4c7ae506e06e6afb4c396995b41ff"
    sha256 cellar: :any_skip_relocation, ventura:       "36815d98ddd9ca57bf3d3635cd15e1b5501765e7ec0bd1f27d4ebf472e061f98"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "ea06e851273ab26e29fb07322d919cf3e37bcf54a62099c42e1c3baff28adf29"
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
