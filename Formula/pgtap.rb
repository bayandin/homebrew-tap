class Pgtap < Formula
  desc "PostgreSQL Unit Testing Suite"
  homepage "https://pgtap.org"
  url "https://github.com/theory/pgtap/archive/refs/tags/v1.3.2.tar.gz"
  sha256 "8441d541dae7ddfcda72585e70074f420978af78a211b9bc48d87bdfe892ce13"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "3ba7e69a58729eb91da602b1c3c3ef597a112e9636ca43409e16d9e551dd58f3"
    sha256 cellar: :any_skip_relocation, ventura:      "0e5c14ee101b48611d2ecb84a4d1767ea1096f53613bf99dfc72f22cf45d74ff"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "03faeda05de1f8c561791d4a097ebde2d8f360b1647228060ec2a1aae0ab272e"
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
