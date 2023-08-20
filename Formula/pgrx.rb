class Pgrx < Formula
  desc "Build Postgres Extensions with Rust"
  homepage "https://github.com/pgcentralfoundation/pgrx"
  url "https://github.com/pgcentralfoundation/pgrx/archive/refs/tags/v0.9.8.tar.gz"
  sha256 "b905bc2097bf720a1266197466212bfe0815edb95ff762264bbe31dbcf6bc305"
  license "MIT"

  depends_on "postgresql@15" => :test
  depends_on "rust"

  def install
    system "cargo", "install", *std_cargo_args(path: "cargo-pgrx")
  end

  test do
    system "cargo", "pgrx", "init", "--pg15", Formula["postgresql@15"].opt_bin/"pg_config"
    system "cargo", "pgrx", "new", "example"
    cd "example" do
      # Postgres symbols won't be available until runtime
      ENV["RUSTFLAGS"] = "-Clink-arg=-Wl,-undefined,dynamic_lookup"

      system "cargo", "pgrx", "package", "--pg-config", Formula["postgresql@15"].opt_bin/"pg_config",
                                         "--out-dir", testpath/"out"
    end
  end
end
