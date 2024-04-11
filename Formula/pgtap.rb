class Pgtap < Formula
  desc "PostgreSQL Unit Testing Suite"
  homepage "https://pgtap.org"
  url "https://github.com/theory/pgtap/archive/refs/tags/v1.3.3.tar.gz"
  sha256 "325ea79d0d2515bce96bce43f6823dcd3effbd6c54cb2a4d6c2384fffa3a14c7"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "3f1ccbcc2cbb7088a01c91193ffb2c55a9aae30fd93f4012a14310a884f6be0d"
    sha256 cellar: :any_skip_relocation, ventura:      "49ee8ac82f99a02ba91a2a15d7c6d9072155ccc4de3cb6e4c9a103bc006d4576"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "843e442e8b059272299a402650c4cffa8a26971c898b5e002872dfac834aea55"
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
