class PlpgsqlCheck < Formula
  desc "Plpgsql linter"
  homepage "https://github.com/okbob/plpgsql_check"
  url "https://github.com/okbob/plpgsql_check/archive/refs/tags/v2.8.0.tar.gz"
  sha256 "46a69c4d8b68e9ee0ef19fc5ee407c0b5f2388e579398f4fc129df345057f47c"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "751718a5c1b9da5aaa286a48a6401b2e276bb62b12c6a0f80d5aad051aa264b7"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "ab8f31588d788bb2df2fc58426d250030a53dd98479ed752d23f47689e68e894"
    sha256 cellar: :any_skip_relocation, ventura:       "fca67088f459c786505ba78b389524db9e3c73f13e0c8fb911e949815ea2621b"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "6ae3755986e87158f044c2516483c09fe857a43329587e48a2b13d0430a4201b"
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
