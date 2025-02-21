class PgGraphql < Formula
  desc "GraphQL support for PostgreSQL"
  homepage "https://supabase.github.io/pg_graphql"
  url "https://github.com/supabase/pg_graphql/archive/refs/tags/v1.5.11.tar.gz"
  sha256 "b93d195e3306bfcfbad51b7bc24d2873e7f42223448044cb6b0aecdb9e60de45"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    rebuild 1
    sha256 cellar: :any,                 arm64_sequoia: "797b9598f7312a541591094af3c191621d4c1a9c32014b60533e634243eca8a2"
    sha256 cellar: :any,                 arm64_sonoma:  "ae5aab58e7c648ebf05308212b9698dbe99a0de388b583e1bfdce8e65c0145aa"
    sha256 cellar: :any,                 ventura:       "57a7f193375b633dd32cb2c276e19a45a5be9e8360b653ddae988548314e7d69"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "02735d402544c3b2b43d09f65b492fac33f39e83332a188666dc2945d23a2657"
  end

  depends_on "rust" => :build
  depends_on "bayandin/tap/neon-postgres"

  uses_from_macos "llvm" => :build

  resource "pgrx" do
    url "https://github.com/pgcentralfoundation/pgrx/archive/refs/tags/v0.12.9.tar.gz"
    sha256 "53358008dd2d63293539440b03099cdf7165f8078f1000ed6ad4ed67064309d4"
  end

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def pg_versions
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
      system "cargo", "pgrx", "package", "--profile", "release",
                                        "--pg-config", neon_postgres.pg_bin_for(v)/"pg_config",
                                        "--out-dir", "stage-#{v}"

      stage_dir = Pathname("stage-#{v}#{HOMEBREW_PREFIX}")
      mkdir_p lib/neon_postgres.name/v
      mv stage_dir/"lib/neon-postgres/#{v}/pg_graphql.#{neon_postgres.dlsuffix(v)}", lib/neon_postgres.name/v

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
