class PostgresqlUnit < Formula
  desc "SI Units for PostgreSQL"
  homepage "https://github.com/df7cb/postgresql-unit"
  url "https://github.com/df7cb/postgresql-unit/archive/refs/tags/7.8.tar.gz"
  sha256 "4709d439fba972ec4a0581f6a1504d120a0891dff706cc2c3b82025b000bf89d"
  license "GPL-3.0-or-later"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "583151b639c2df44e4e8296d1473017dd64493f4eb2394018b3de181e0f92844"
    sha256 cellar: :any_skip_relocation, ventura:       "a26fd9d9e0099c3ca45bd61da778bae92627d3ec4a317c281541329ddbc02779"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "c4d3d5ef31d9c1ec8ae4be0d9359e54d407cc32675fbf9ef813ae5db8b5b6b4c"
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
      mv "unit.#{dlsuffix}", lib/neon_postgres.name/v

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
