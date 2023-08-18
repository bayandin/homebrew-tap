class Pgjwt < Formula
  desc "PostgreSQL implementation of JWT (JSON Web Tokens)"
  homepage "https://github.com/michelp/pgjwt"
  url "https://github.com/michelp/pgjwt/archive/f3d82fd30151e754e19ce5d6a06c71c20689ce3d.tar.gz"
  version "2.0"
  sha256 "dae8ed99eebb7593b43013f6532d772b12dfecd55548d2673f2dfd0163f6d2b9"
  license "MIT"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "0180e57c62528911155d8f1fb7b78b542f5fb41a3ab4e866e47cdabd58cffc82"
    sha256 cellar: :any_skip_relocation, ventura:       "ce90599daefe97246026c5d82bc40fcf82e194f98a08abb6289e6c1b31ea0ebf"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "89bb87bb8ca6188adb88e7e12687238fe33a01071cd3900e8618a762c685ffde"
  end

  depends_on "bayandin/tap/neon-postgres"

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def install
    neon_postgres.pg_versions.each do |v|
      system "make", "clean", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"
      system "make", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "pgjwt.control", share/neon_postgres.name/v/"extension"
      cp Dir["pgjwt--*.sql"], share/neon_postgres.name/v/"extension"
    end
  end

  test do
    neon_postgres.pg_versions.each do |v|
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
          CREATE EXTENSION pgcrypto;
          CREATE EXTENSION pgjwt;
          SELECT sign('{"sub":"1234567890","name":"John Doe","admin":true}', 'secret');
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
