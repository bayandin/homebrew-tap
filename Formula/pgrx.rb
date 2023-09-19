class Pgrx < Formula
  desc "Build Postgres Extensions with Rust"
  homepage "https://github.com/pgcentralfoundation/pgrx"
  url "https://github.com/pgcentralfoundation/pgrx/archive/refs/tags/v0.10.2.tar.gz"
  sha256 "040fd7195fc350ec7c823e7c2dcafad2cf621c8696fd2ce0db7626d7fbd3d877"
  license "MIT"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "33350995415d43a64e1b786d6fd1c05f52eb537532c98e9273a7480dc98a9434"
    sha256 cellar: :any_skip_relocation, ventura:       "0dc8f86ff98bd77c8dca928ee7ffe179ab4a9cd08ae17ad1b4f99d572a4f23c7"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "2bc3044026de74e4e73a2e0baeceecf01bf8cfb7f0549400aeadc25d3c518887"
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
