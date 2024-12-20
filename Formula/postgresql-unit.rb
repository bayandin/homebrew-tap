class PostgresqlUnit < Formula
  desc "SI Units for PostgreSQL"
  homepage "https://github.com/df7cb/postgresql-unit"
  url "https://github.com/df7cb/postgresql-unit/archive/refs/tags/7.10.tar.gz"
  sha256 "95bd28deba70bd7d5a28ddceb28fa8dcabbb0821851e8ef62207459d780a2d70"
  license "GPL-3.0-or-later"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "8d28c4c922c1aab3099e0ed2ea22e20a0e257e38180cb02da9c8f7930676a607"
    sha256 cellar: :any_skip_relocation, ventura:      "ba24237bcbef3c5d8dd1d0da239feed6ec2638e6617cec567785a385f172c8ba"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "f732dc070bc7dce8ccc4a42d4474ca455b2adfe9d3023329ca448dc77b86a382"
  end

  depends_on "bayandin/tap/neon-postgres"

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def pg_versions
    neon_postgres.pg_versions(with: "v17")
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
