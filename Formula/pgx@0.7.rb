class PgxAT07 < Formula
  desc "Build Postgres Extensions with Rust"
  homepage "https://github.com/pgcentralfoundation/pgrx"
  url "https://github.com/pgcentralfoundation/pgrx/archive/refs/tags/v0.7.4.tar.gz"
  sha256 "b4ac29b0fbe04abb27496008fa9a6b787d27f579ba88b540862d33579a515ea6"
  license "MIT"

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
