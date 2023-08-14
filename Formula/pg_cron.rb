class PgCron < Formula
  desc "Run periodic jobs in PostgreSQL"
  homepage "https://github.com/citusdata/pg_cron"
  url "https://github.com/citusdata/pg_cron/archive/refs/tags/v1.5.2.tar.gz"
  sha256 "6f7f0980c03f1e2a6a747060e67bf4a303ca2a50e941e2c19daeed2b44dec744"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_ventura: "b670ad612ca059a9a646cee02c222dd2414f7e82bb4fe787027e3b1163c91684"
    sha256 cellar: :any,                 ventura:       "8bf8cdc02a691ca58787775d4bdf7907a85f2da972bb4ddb6155e00a1797cde2"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "e2b76979d78b29e0ebf320438c0b60cb19c0c87b6ca7eedb45f242a88b6a3151"
  end

  depends_on "bayandin/tap/neon-postgres"

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def install
    neon_postgres.pg_versions.each do |v|
      ENV["PG_CONFIG"] = neon_postgres.pg_bin_for(v)/"pg_config"
      system "make", "clean"
      system "make"

      mkdir_p lib/neon_postgres.name/v
      mv "pg_cron.so", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "pg_cron.control", share/neon_postgres.name/v/"extension"
      cp Dir["pg_cron--*.sql"], share/neon_postgres.name/v/"extension"
    end
  end

  test do
    neon_postgres.pg_versions.each do |v|
      pg_ctl = neon_postgres.pg_bin_for(v)/"pg_ctl"
      psql = neon_postgres.pg_bin_for(v)/"psql"
      port = free_port

      system pg_ctl, "initdb", "-D", testpath/"test-#{v}"
      (testpath/"test-#{v}/postgresql.conf").write <<~EOS, mode: "a+"
        shared_preload_libraries = 'pg_cron'
        port = #{port}
      EOS
      system pg_ctl, "start", "-D", testpath/"test-#{v}", "-l", testpath/"log-#{v}"
      begin
        system psql, "-p", port.to_s, "-c", <<~SQL, "postgres"
          CREATE EXTENSION pg_cron;
          SELECT cron.schedule('nightly-vacuum', '0 10 * * *', 'VACUUM');
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
