class PgHashids < Formula
  desc "Short unique id generator for PostgreSQL, using hashids"
  homepage "https://github.com/iCyberon/pg_hashids"
  url "https://github.com/iCyberon/pg_hashids/archive/refs/tags/v1.2.1.tar.gz"
  sha256 "74576b992d9277c92196dd8d816baa2cc2d8046fe102f3dcd7f3c3febed6822a"
  license "MIT"
  revision 1

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "2a991e54c25057f381e042385f91497ad2714294e83f2ba757e5d08357726dd6"
    sha256 cellar: :any_skip_relocation, ventura:       "889a3223a5dce89ed4acf023d4f094f9de82b23c4f1a4c09075955442e606d39"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "05de7f68135034e2ca61a1b62bc18349c828bb2d342e982bf38bdcd6960ba2c1"
  end

  depends_on "bayandin/tap/neon-postgres"

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def pg_versions
    neon_postgres.pg_versions with: "v16"
  end

  def install
    pg_versions.each do |v|
      # Ref https://github.com/postgres/postgres/commit/b55f62abb2c2e07dfae99e19a2b3d7ca9e58dc1a
      dlsuffix = (OS.linux? || "v14 v15".include?(v)) ? "so" : "dylib"

      system "make", "clean", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"
      system "make", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"

      mkdir_p lib/neon_postgres.name/v
      mv "pg_hashids.#{dlsuffix}", lib/neon_postgres.name/v

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
