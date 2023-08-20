class Pgrx < Formula
  desc "Build Postgres Extensions with Rust"
  homepage "https://github.com/pgcentralfoundation/pgrx"
  url "https://github.com/pgcentralfoundation/pgrx/archive/refs/tags/v0.9.8.tar.gz"
  sha256 "b905bc2097bf720a1266197466212bfe0815edb95ff762264bbe31dbcf6bc305"
  license "MIT"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "884d16fd2460993c12d6790b652f0904294e5d79e59b6c30ab868ca82ee70ad3"
    sha256 cellar: :any_skip_relocation, ventura:       "1ff82c222f615e4a1fd193ce6fb61e814126b5e59540c1c99486bf7233f860c9"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "6b3a22f42a870ae886f2d59b0c988752b52e2bbd371970d396088dc2a11cfb62"
  end

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
