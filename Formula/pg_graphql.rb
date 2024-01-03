class PgGraphql < Formula
  desc "GraphQL support for PostgreSQL"
  homepage "https://supabase.github.io/pg_graphql"
  url "https://github.com/supabase/pg_graphql/archive/refs/tags/v1.4.3.tar.gz"
  sha256 "68e3f2bd81b1aeae4605181bb70b71bfcbc7194ab0c13945587467f0f353e6f2"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_ventura: "e80a1f6110e42df0c2855815c524d748f59c97749f88897e450ea6fcab4bd507"
    sha256 cellar: :any,                 ventura:       "c3e3852550558fb0c7dc67e5468f9e4d36e0388ab49870baaf82e60fc846807d"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "ff4a7fe676b1f6683a3d192a70c1c0af63874d75c7b7924274a78c36a1c01887"
  end

  depends_on "rust" => :build
  depends_on "rustfmt" => :build
  depends_on "bayandin/tap/neon-postgres"

  uses_from_macos "llvm" => :build

  resource "pgrx" do
    url "https://github.com/pgcentralfoundation/pgrx/archive/refs/tags/v0.11.2.tar.gz"
    sha256 "2f818d18c86fa292428766c9af52313cd80030e041948d67716f7c4005e4ff38"
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
