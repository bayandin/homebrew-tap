class PgCron < Formula
  desc "Run periodic jobs in PostgreSQL"
  homepage "https://github.com/citusdata/pg_cron"
  url "https://github.com/citusdata/pg_cron/archive/refs/tags/v1.6.7.tar.gz"
  sha256 "d950bc29155f31017567e23a31d268ff672e98276c0e9d062512fb7870351f03"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_sequoia: "766cdf517195204ccbf90c3ac7885ef5e62c3bf79c5db8bb0723ff8e88cb8405"
    sha256 cellar: :any,                 arm64_sonoma:  "57c260a0fe1202bd398387142ec8353df70e83ee1ab84e720df255cf80c1c82a"
    sha256 cellar: :any,                 ventura:       "810611e9e7624a3b6f40157ec54fa22ddfae55e06cf7ec18dd109547e40372dd"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "b56122eeba72c4660a0fa251f2b192276d33ab2dd04d3a3e461694cc26ead4ed"
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
      ENV["PG_CONFIG"] = neon_postgres.pg_bin_for(v)/"pg_config"
      system "make", "clean"
      system "make"

      mkdir_p lib/neon_postgres.name/v
      mv "pg_cron.#{neon_postgres.dlsuffix(v)}", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "pg_cron.control", share/neon_postgres.name/v/"extension"
      cp Dir["pg_cron--*.sql"], share/neon_postgres.name/v/"extension"
    end
  end

  test do
    pg_versions.each do |v|
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
