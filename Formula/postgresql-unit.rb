class PostgresqlUnit < Formula
  desc "SI Units for PostgreSQL"
  homepage "https://github.com/df7cb/postgresql-unit"
  url "https://github.com/df7cb/postgresql-unit/archive/refs/tags/7.10.tar.gz"
  sha256 "95bd28deba70bd7d5a28ddceb28fa8dcabbb0821851e8ef62207459d780a2d70"
  license "GPL-3.0-or-later"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "3bdd402ec5d72ab1457469118bf850695265582e27a3f6975022279bfb327cdb"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "5209a8029531650aa0f445ad43e19de7db090304bbe81c06b100a7fa45a3691f"
    sha256 cellar: :any_skip_relocation, ventura:       "f43ad7870a26cac77f2daab22bf07799eceab2af6ed474b74073a4e8a4d512a6"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "c4f0c0dff82237c14d8685b39ebf563b69ec2e8ec156e83f5e6993d508648096"
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
      mv "unit.#{neon_postgres.dlsuffix(v)}", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "unit.control", share/neon_postgres.name/v/"extension"
      cp Dir["unit--*.sql"], share/neon_postgres.name/v/"extension"
      cp Dir["*.data"], share/neon_postgres.name/v/"extension"
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
          CREATE EXTENSION unit;
          SELECT '800 m'::unit + '500 m' AS length;
          SELECT '25m'::unit @ 'ft'
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
