class PlpgsqlCheck < Formula
  desc "Plpgsql linter"
  homepage "https://github.com/okbob/plpgsql_check"
  url "https://github.com/okbob/plpgsql_check/archive/refs/tags/v2.7.14.tar.gz"
  sha256 "f982f4a6f76cb7caaf8e298cd0db9c7ca46c1c8444aa4cd42f65d3fca481382b"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "6b721d288cbcee5ad1d575f223313f6b3480a07ea2a0c8af8d6b497a81a5f231"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "4d47a17c3163baf788883180317b63375e934cfaed17e36422381f56d91e4808"
    sha256 cellar: :any_skip_relocation, ventura:       "01e98d3e9f923bc44d108f6a3b59dc9c6e67cb7c9371fdc74d394c9d9f43eeab"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "1a80f57f3d29659c2c3e0d3c7cabd7eb314ab1c98a4183824484480eaaec7854"
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
