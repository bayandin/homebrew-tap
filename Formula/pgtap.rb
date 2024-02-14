class Pgtap < Formula
  desc "PostgreSQL Unit Testing Suite"
  homepage "https://pgtap.org"
  url "https://github.com/theory/pgtap/archive/refs/tags/v1.3.2.tar.gz"
  sha256 "8441d541dae7ddfcda72585e70074f420978af78a211b9bc48d87bdfe892ce13"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "38cb7b0d15c3a33d13888ff384fe307da2766057984ee634fc0c35b8bdf80efc"
    sha256 cellar: :any_skip_relocation, ventura:       "3d8016179681076642a8e00dde6e064ae76280608e0ad882ae2de671e60a573c"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "f6a06040a4f50d5614f3ff214029d1fb3294fba50d051051a4ab37393c24dd94"
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

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "pgtap.control", share/neon_postgres.name/v/"extension"
      cp Dir["sql/pgtap--*.sql"], share/neon_postgres.name/v/"extension"
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
          CREATE EXTENSION pgtap;
          -- Start transaction and plan the tests.
          BEGIN;
          SELECT plan(1);

          -- Run the tests.
          SELECT pass( 'My test passed, w00t!' );

          -- Finish the tests and clean up.
          SELECT * FROM finish();
          ROLLBACK;
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
