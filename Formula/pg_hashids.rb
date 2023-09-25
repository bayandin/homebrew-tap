class PgHashids < Formula
  desc "Short unique id generator for PostgreSQL, using hashids"
  homepage "https://github.com/iCyberon/pg_hashids"
  url "https://github.com/iCyberon/pg_hashids/archive/refs/tags/v1.2.1.tar.gz"
  sha256 "74576b992d9277c92196dd8d816baa2cc2d8046fe102f3dcd7f3c3febed6822a"
  license "MIT"
  revision 1

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "e64f08496229e20a1628a4a4cc5e8b5d0438820b6fd0f0e3dedcec82a5eedc3a"
    sha256 cellar: :any_skip_relocation, ventura:       "c417dd5d763fb05d3c77d6afb17f866858a28b6e2c9fd3c734f20a279224a329"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "5c0f54cef24350ef41cbdbdeb6e6f7676cc7f7434d0f8fbe786f158c60c6215a"
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
