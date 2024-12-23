class Pgtap < Formula
  desc "PostgreSQL Unit Testing Suite"
  homepage "https://pgtap.org"
  url "https://github.com/theory/pgtap/archive/refs/tags/v1.3.3.tar.gz"
  sha256 "325ea79d0d2515bce96bce43f6823dcd3effbd6c54cb2a4d6c2384fffa3a14c7"
  license "PostgreSQL"
  revision 1

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "31b53f5f3461c7325fc5a41332024bc460fd40f821bcded12d4089d50dc79549"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "b9e0b7732605aef3f6ef0075a7f94e8284b4bd46cbd5eb93e127e2be73c9ed09"
    sha256 cellar: :any_skip_relocation, ventura:       "7fbcafd9100fb3b1a9ce96bc9bbab23f9d059fd15e8196ca8f487926d0a899b5"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "388afdf1da783d166ecde1660d15efaa5c29ed5c93b4fadfca6c670c0278b459"
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
