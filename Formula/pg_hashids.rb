class PgHashids < Formula
  desc "Short unique id generator for PostgreSQL, using hashids"
  homepage "https://github.com/iCyberon/pg_hashids"
  url "https://github.com/iCyberon/pg_hashids/archive/refs/tags/v1.2.1.tar.gz"
  sha256 "74576b992d9277c92196dd8d816baa2cc2d8046fe102f3dcd7f3c3febed6822a"
  license "MIT"

  depends_on "bayandin/tap/neon-postgres"

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def install
    neon_postgres.pg_versions.each do |v|
      system "make", "clean", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"
      system "make", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"

      mkdir_p lib/neon_postgres.name/v
      mv "pg_hashids.so", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "pg_hashids.control", share/neon_postgres.name/v/"extension"
      cp Dir["pg_hashids--*.sql"], share/neon_postgres.name/v/"extension"
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
          CREATE EXTENSION pg_hashids;
          SELECT id_encode(1001);
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
