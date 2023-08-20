class PgxAT07 < Formula
  desc "Build Postgres Extensions with Rust"
  homepage "https://github.com/pgcentralfoundation/pgrx"
  url "https://github.com/pgcentralfoundation/pgrx/archive/refs/tags/v0.7.4.tar.gz"
  sha256 "b4ac29b0fbe04abb27496008fa9a6b787d27f579ba88b540862d33579a515ea6"
  license "MIT"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "badf7d6d965ebc64875d7669885bb184229995568ecad8131c21cc6b4d200ed0"
    sha256 cellar: :any_skip_relocation, ventura:       "82a7725345bd45be0a9f34c9605bf16817afdc646326aa3d847c46d2ae1f7d9a"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "69375cce06b78cf03e4f24e751f6aa6a78eca5dd475682752a8433ca1adb7c74"
  end

  depends_on "postgresql@15" => :test
  depends_on "rust"

  def install
    system "cargo", "install", *std_cargo_args(path: "cargo-pgx")
  end

  test do
    system "cargo", "pgx", "init", "--pg15", Formula["postgresql@15"].opt_bin/"pg_config"
    system "cargo", "pgx", "new", "example"
    cd "example" do
      # Postgres symbols won't be available until runtime
      ENV["RUSTFLAGS"] = "-Clink-arg=-Wl,-undefined,dynamic_lookup"

      system "cargo", "pgx", "package", "--pg-config", Formula["postgresql@15"].opt_bin/"pg_config",
                                        "--out-dir", testpath/"out"
    end
  end
end
