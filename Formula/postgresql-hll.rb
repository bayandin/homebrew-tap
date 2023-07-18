class PostgresqlHll < Formula
  desc "PostgreSQL extension adding HyperLogLog data structures as a native data type"
  homepage "https://github.com/citusdata/postgresql-hll"
  url "https://github.com/citusdata/postgresql-hll/archive/refs/tags/v2.17.tar.gz"
  sha256 "9a18288e884f197196b0d29b9f178ba595b0dfc21fbf7a8699380e77fa04c1e9"
  license "Apache-2.0"

  depends_on "bayandin/tap/neon-postgres"

  def pg_versions
    %w[v14 v15]
  end

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def install
    pg_versions.each do |v|
      ENV["PG_CONFIG"] = neon_postgres.opt_libexec/v/"bin/pg_config"
      system "make", "clean"
      system "make"

      mkdir_p lib/neon_postgres.name/v
      mv "hll.so", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "hll.control", share/neon_postgres.name/v/"extension"
      cp Dir["hll--*.sql"], share/neon_postgres.name/v/"extension"
    end
  end

  test do
    pg_versions.each do |v|
      pg_ctl = neon_postgres.opt_libexec/v/"bin/pg_ctl"
      psql = neon_postgres.opt_libexec/v/"bin/psql"
      port = free_port

      system pg_ctl, "initdb", "-D", testpath/"test-#{v}"
      (testpath/"test-#{v}/postgresql.conf").write <<~EOS, mode: "a+"
        port = #{port}
      EOS
      system pg_ctl, "start", "-D", testpath/"test-#{v}", "-l", testpath/"log-#{v}"
      begin
        system psql, "-p", port.to_s, "-c", <<~SQL, "postgres"
          CREATE EXTENSION hll;
          CREATE TABLE helloworld (id integer, set hll);
          INSERT INTO helloworld(id, set) VALUES (1, hll_empty());
          UPDATE helloworld SET set = hll_add(set, hll_hash_integer(12345)) WHERE id = 1;
          UPDATE helloworld SET set = hll_add(set, hll_hash_text('hello world')) WHERE id = 1;
          SELECT hll_cardinality(set) FROM helloworld WHERE id = 1;
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
