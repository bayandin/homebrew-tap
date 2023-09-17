class Pgrx < Formula
  desc "Build Postgres Extensions with Rust"
  homepage "https://github.com/pgcentralfoundation/pgrx"
  url "https://github.com/pgcentralfoundation/pgrx/archive/refs/tags/v0.10.1.tar.gz"
  sha256 "b93b3e75dd7484c14e383ccb7f026d6b6cbec584fdb476c9c4f670a9e745ae50"
  license "MIT"
  revision 1

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "5ce73c7d3cf042b2ed2887b6b84247da2ad4c7ae506e06e6afb4c396995b41ff"
    sha256 cellar: :any_skip_relocation, ventura:       "36815d98ddd9ca57bf3d3635cd15e1b5501765e7ec0bd1f27d4ebf472e061f98"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "ea06e851273ab26e29fb07322d919cf3e37bcf54a62099c42e1c3baff28adf29"
  end

  depends_on "postgresql@16" => :test
  depends_on "rust"
  depends_on "rustfmt"

  # Fix for Postgres 16 on macOS
  patch do
    url "https://gist.githubusercontent.com/bayandin/f89ddb6af47ac994a325ba856c68e7d1/raw/0aa70e53afb60391bbb9e8fb7c1a30887a7df8bf/0001-Fix-install-for-Postgres-16-on-macOS.patch"
    sha256 "86ca94cdef8dd3e1211eabb5f104787bc166b4dc3ce5c6f42a454a1d0fac9613"
  end

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
