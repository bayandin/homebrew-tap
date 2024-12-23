class Pgjwt < Formula
  desc "PostgreSQL implementation of JWT (JSON Web Tokens)"
  homepage "https://github.com/michelp/pgjwt"
  url "https://github.com/michelp/pgjwt/archive/f3d82fd30151e754e19ce5d6a06c71c20689ce3d.tar.gz"
  version "2.0"
  sha256 "dae8ed99eebb7593b43013f6532d772b12dfecd55548d2673f2dfd0163f6d2b9"
  license "MIT"
  revision 2

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "f84530e08ff4dc52db7a68b856244c5d0b16ea606968a0c813f4c41d70f4a620"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "b7a20370d3ba0fca073ecfce74308abf9e4a905baa314fa2d1b98d8fb878b52a"
    sha256 cellar: :any_skip_relocation, ventura:       "2fd2a2d82e5d04b1a1364feb94ee9b9ee41102f4f0db9526c1067970492630e8"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "7c5d0ccdfec3f632ed92f0234741a92bf7a4019965b63cc6901561b390ccba66"
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
      cp "pgjwt.control", share/neon_postgres.name/v/"extension"
      cp Dir["pgjwt--*.sql"], share/neon_postgres.name/v/"extension"
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
          CREATE EXTENSION pgjwt CASCADE;
          SELECT sign('{"sub":"1234567890","name":"John Doe","admin":true}', 'secret');
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
