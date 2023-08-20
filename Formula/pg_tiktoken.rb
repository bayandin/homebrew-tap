class PgTiktoken < Formula
  desc "Tiktoken tokenizer for PostgreSQL"
  homepage "https://github.com/kelvich/pg_tiktoken"
  url "https://github.com/kelvich/pg_tiktoken/archive/801f84f08c6881c8aa30f405fafbf00eec386a72.tar.gz"
  version "0.0.1"
  sha256 "52f60ac800993a49aa8c609961842b611b6b1949717b69ce2ec9117117e16e4a"

  depends_on "pgx@0.7" => :build
  depends_on "rust" => :build
  depends_on "bayandin/tap/neon-postgres"

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def install
    # Postgres symbols won't be available until runtime
    ENV["RUSTFLAGS"] = "-Clink-arg=-Wl,-undefined,dynamic_lookup"

    args = []
    neon_postgres.pg_versions.each do |v|
      args << "--pg#{v.delete_prefix("v")}" << (neon_postgres.pg_bin_for(v)/"pg_config")
    end
    system "cargo", "pgx", "init", *args

    neon_postgres.pg_versions.each do |v|
      system "cargo", "pgx", "package", "--profile", "release",
                                        "--pg-config", neon_postgres.pg_bin_for(v)/"pg_config",
                                        "--out-dir", "stage-#{v}"

      stage_dir = Pathname("stage-#{v}#{HOMEBREW_PREFIX}")
      mkdir_p lib/neon_postgres.name/v
      mv stage_dir/"lib/neon-postgres/#{v}/pg_tiktoken.so", lib/neon_postgres.name/v

      from_ext_dir = stage_dir/"share/neon-postgres/#{v}/extension"
      to_ext_dir = share/neon_postgres.name/v/"extension"

      mkdir_p to_ext_dir
      mv from_ext_dir/"pg_tiktoken.control", to_ext_dir
      mv Dir[from_ext_dir/"pg_tiktoken--*.sql"], to_ext_dir
    end
  end

  test do
    neon_postgres.pg_versions.each do |v|
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
          CREATE EXTENSION pg_tiktoken;
          SELECT tiktoken_encode('cl100k_base', 'A long time ago in a galaxy far, far away');
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
