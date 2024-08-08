class PlpgsqlCheck < Formula
  desc "Plpgsql linter"
  homepage "https://github.com/okbob/plpgsql_check"
  url "https://github.com/okbob/plpgsql_check/archive/refs/tags/v2.7.8.tar.gz"
  sha256 "082ff90c5e4c24355dd6a35815c6f82bcb04456465ca656921df6b95b8b8b23a"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "609c401b6e9fa412cfdec168e36c924e7e50a3e2dc1ef3d4e8e427fbc62177e2"
    sha256 cellar: :any_skip_relocation, ventura:      "3daa599537453eabc9d9a9be9af4ceee5095dea616acc5bfebb35539bff0f414"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "b6dbf6c2d474ed4eb08435e40118470315db7ed6622a5dbe4b0cd5b9490770de"
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
