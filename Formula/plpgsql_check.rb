class PlpgsqlCheck < Formula
  desc "Plpgsql linter"
  homepage "https://github.com/okbob/plpgsql_check"
  url "https://github.com/okbob/plpgsql_check/archive/refs/tags/v2.8.2.tar.gz"
  sha256 "66cb840ab8b18d06077827e316800a2d92ed483f9bbacbfad6d4a2e8e26f4048"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "31e71a4ec4201fe5c378ea464770eed242a4e87c8986e0c1bc9445e76fd42a9f"
    sha256 cellar: :any_skip_relocation, ventura:       "2a34d4345c4aa52a6bc87129550297d8763543d943fbad33865d869874f242eb"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "4cdc3e6c2199f31a790d798777c509a5299e61a8ce8e0fd40f12dd182ad36811"
  end

  depends_on "bayandin/tap/neon-postgres"

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def pg_versions
    neon_postgres.pg_versions
  end

  def install
    pg_versions.each do |v|
      system "make", "clean", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"
      system "make", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"

      mkdir_p lib/neon_postgres.name/v
      mv "plpgsql_check.#{neon_postgres.dlsuffix(v)}", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "plpgsql_check.control", share/neon_postgres.name/v/"extension"
      cp Dir["plpgsql_check--*.sql"], share/neon_postgres.name/v/"extension"
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
          CREATE EXTENSION plpgsql_check;

          CREATE TABLE t1(a int, b int);
          CREATE OR REPLACE FUNCTION public.f1()
          RETURNS void
          LANGUAGE plpgsql
          AS $function$
          DECLARE r record;
          BEGIN
            FOR r IN SELECT * FROM t1
            LOOP
              RAISE NOTICE '%', r.c; -- there is bug - table t1 missing "c" column
            END LOOP;
          END;
          $function$;

          SELECT * FROM plpgsql_check_function_tb('f1()');
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
