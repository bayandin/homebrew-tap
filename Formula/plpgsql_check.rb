class PlpgsqlCheck < Formula
  desc "Plpgsql linter"
  homepage "https://github.com/okbob/plpgsql_check"
  url "https://github.com/okbob/plpgsql_check/archive/refs/tags/v2.5.4.tar.gz"
  sha256 "27f50e670a6a8eebf039090cde3678c46f8870fbc0326eddb1863edc666912c3"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "4d7f32cc1f701681a5e3938be482554f7422b7920762f49c2f3e67c0ed14787e"
    sha256 cellar: :any_skip_relocation, ventura:       "999308f05ef08f00ba45721cb610e62a017bff5ff001447a844b31aedcc46130"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "709f94f2097a89c85bfdfecb8a990dafa9d99b1b637bf8fed98aa8b641dc994e"
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
      # Ref https://github.com/postgres/postgres/commit/b55f62abb2c2e07dfae99e19a2b3d7ca9e58dc1a
      dlsuffix = (OS.linux? || "v14 v15".include?(v)) ? "so" : "dylib"

      system "make", "clean", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"
      system "make", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"

      mkdir_p lib/neon_postgres.name/v
      mv "plpgsql_check.#{dlsuffix}", lib/neon_postgres.name/v

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
