class PgJsonschema < Formula
  desc "PostgreSQL extension providing JSON Schema validation"
  homepage "https://github.com/supabase/pg_jsonschema"
  url "https://github.com/supabase/pg_jsonschema/archive/refs/tags/v0.3.3.tar.gz"
  sha256 "40c2cffab4187e0233cb8c3bde013be92218c282f95f4469c5282f6b30d64eac"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_sequoia: "c3447585065cc1079749a733d22da6909ba2d81e970d06959023596bab0b82ae"
    sha256 cellar: :any,                 arm64_sonoma:  "34421242ae96717e8e8f24cab435c8f80c6b22d94d4d32708bee28829368cf0e"
    sha256 cellar: :any,                 ventura:       "b33a58690e88fde91de6f42f5703b6f0c82da4aee0f8cdaced7c4621f362f330"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "683159a28d34fa6b597eb59d4bc7c0699228f871c45294146e3743eb5d33315e"
  end

  depends_on "rust" => :build
  depends_on "bayandin/tap/neon-postgres"

  uses_from_macos "llvm" => :build

  resource "pgrx" do
    url "https://github.com/pgcentralfoundation/pgrx/archive/refs/tags/v0.12.6.tar.gz"
    sha256 "ba04f50b3f9f160a1c70861ad2358b3eb6485dbc13608eef09b4094460487a57"
  end

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def pg_versions
    neon_postgres.pg_versions(with: "v17")
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
      mv stage_dir/"lib/neon-postgres/#{v}/pg_jsonschema.#{neon_postgres.dlsuffix(v)}", lib/neon_postgres.name/v

      from_ext_dir = stage_dir/"share/neon-postgres/#{v}/extension"
      to_ext_dir = share/neon_postgres.name/v/"extension"

      mkdir_p to_ext_dir
      mv from_ext_dir/"pg_jsonschema.control", to_ext_dir
      mv Dir[from_ext_dir/"pg_jsonschema--*.sql"], to_ext_dir
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
          CREATE EXTENSION pg_jsonschema;
          SELECT json_matches_schema('{"type": "object"}', '{}');
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
