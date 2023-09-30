class PgGraphql < Formula
  desc "GraphQL support for PostgreSQL"
  homepage "https://supabase.github.io/pg_graphql"
  url "https://github.com/supabase/pg_graphql/archive/refs/tags/v1.3.0.tar.gz"
  sha256 "d76d5e479a1f0233701fb336e90d1ed58054e16dc182f676dfc3afd04d82b7c6"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_ventura: "f6718a0e3fd7308fc3076d35dcc8cd9656f9b67d8984d19335387d4ce880b044"
    sha256 cellar: :any,                 ventura:       "2d6e895618aadc93294461f9a6211cae9c762429b7f49ee6fdeedf240a50c441"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "b682e5df24ca1a58771bfab260d208f976bb9ab86a78783c249ab931f168bef2"
  end

  depends_on "rust" => :build
  depends_on "rustfmt" => :build
  depends_on "bayandin/tap/neon-postgres"

  uses_from_macos "llvm" => :build

  resource "pgrx" do
    url "https://github.com/pgcentralfoundation/pgrx/archive/refs/tags/v0.9.8.tar.gz"
    sha256 "b905bc2097bf720a1266197466212bfe0815edb95ff762264bbe31dbcf6bc305"
  end

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def pg_versions
    # Add with: `with: "v16"` in the next release (>=1.4)
    neon_postgres.pg_versions
  end

  def install
    resource("pgrx").stage do
      system "cargo", "install", *std_cargo_args(root: buildpath/"pgrx", path: "cargo-pgrx")
      ENV.prepend_path "PATH", buildpath/"pgrx/bin"
    end

    inreplace "Cargo.toml", /pgrx = "([^"]+)"/,
                            "pgrx = { version = \"\\1\", features = [ \"unsafe-postgres\" ] }"

    # Postgres symbols won't be available until runtime
    ENV["RUSTFLAGS"] = "-Clink-arg=-Wl,-undefined,dynamic_lookup"

    args = []
    pg_versions.each do |v|
      args << "--pg#{v.delete_prefix("v")}" << (neon_postgres.pg_bin_for(v)/"pg_config")
    end
    system "cargo", "pgrx", "init", *args

    pg_versions.each do |v|
      # Ref https://github.com/postgres/postgres/commit/b55f62abb2c2e07dfae99e19a2b3d7ca9e58dc1a
      dlsuffix = (OS.linux? || "v14 v15".include?(v)) ? "so" : "dylib"

      system "cargo", "pgrx", "package", "--profile", "release",
                                        "--pg-config", neon_postgres.pg_bin_for(v)/"pg_config",
                                        "--out-dir", "stage-#{v}"

      stage_dir = Pathname("stage-#{v}#{HOMEBREW_PREFIX}")
      mkdir_p lib/neon_postgres.name/v
      mv stage_dir/"lib/neon-postgres/#{v}/pg_graphql.#{dlsuffix}", lib/neon_postgres.name/v

      from_ext_dir = stage_dir/"share/neon-postgres/#{v}/extension"
      to_ext_dir = share/neon_postgres.name/v/"extension"

      mkdir_p to_ext_dir
      mv from_ext_dir/"pg_graphql.control", to_ext_dir
      mv Dir[from_ext_dir/"pg_graphql--*.sql"], to_ext_dir
    end
  end

  test do
    pg_versions.each do |v|
      pg_ctl = neon_postgres.pg_bin_for(v)/"pg_ctl"
      psql = neon_postgres.pg_bin_for(v)/"psql"
      port = free_port

      system pg_ctl, "initdb", "-D", testpath/"test-#{v}"
      (testpath/"test-#{v}/postgresql.conf").write <<~EOS, mode: "a+"
        port = #{port}
      EOS
      system pg_ctl, "start", "-D", testpath/"test-#{v}", "-l", testpath/"log-#{v}"
      begin
        system psql, "-p", port.to_s, "-c", <<~SQL, "postgres"
          CREATE EXTENSION pg_graphql;
          CREATE TABLE book(id INT PRIMARY KEY, title TEXT);
          INSERT INTO book(id, title) VALUES (1, 'book 1');
          SELECT graphql.resolve($$
            query {
              bookCollection {
                edges {
                  node {
                    id
                  }
                }
              }
            }
          $$);
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
