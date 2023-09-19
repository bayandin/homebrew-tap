class Pgrx < Formula
  desc "Build Postgres Extensions with Rust"
  homepage "https://github.com/pgcentralfoundation/pgrx"
  url "https://github.com/pgcentralfoundation/pgrx/archive/refs/tags/v0.10.2.tar.gz"
  sha256 "040fd7195fc350ec7c823e7c2dcafad2cf621c8696fd2ce0db7626d7fbd3d877"
  license "MIT"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "47386f8c2dc4a7c855621c47c2184d91542eeb50eac96d44dc8a195fd64d0303"
    sha256 cellar: :any_skip_relocation, ventura:       "0c597b0bcf4d1123bf895fd71026854a35b1778efd351cbe237ce492cf894a49"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "628cf76bb6853a827929a8ac06a17a9f597431f34f04d5a2f9f9726193cb173e"
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
