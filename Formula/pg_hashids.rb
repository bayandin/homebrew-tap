class PgHashids < Formula
  desc "Short unique id generator for PostgreSQL, using hashids"
  homepage "https://github.com/iCyberon/pg_hashids"
  url "https://github.com/iCyberon/pg_hashids/archive/refs/tags/v1.2.1.tar.gz"
  sha256 "74576b992d9277c92196dd8d816baa2cc2d8046fe102f3dcd7f3c3febed6822a"
  license "MIT"
  revision 2

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "c7e2b0e267f4e17df4ae1ea76326906b817d77a973956fd555b6850794b085c6"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "48ed778ab2f0fdf0a05c6d835f352e1d40bd7b9cf67ebe3330137cbff32056e6"
    sha256 cellar: :any_skip_relocation, ventura:       "248f0744fe2a51fa507bbc400e80f7eeca50de438e549f7b8214cb715111c74d"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "71b207ce4f25724a6e56039e41ba7736181c17d4b6750239145217be1d1cfa73"
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
      mv "pg_hashids.#{neon_postgres.dlsuffix(v)}", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "pg_hashids.control", share/neon_postgres.name/v/"extension"
      cp Dir["pg_hashids--*.sql"], share/neon_postgres.name/v/"extension"
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
          CREATE EXTENSION pg_hashids;
          SELECT id_encode(1001);
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
