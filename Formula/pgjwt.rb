class Pgjwt < Formula
  desc "PostgreSQL implementation of JWT (JSON Web Tokens)"
  homepage "https://github.com/michelp/pgjwt"
  url "https://github.com/michelp/pgjwt/archive/f3d82fd30151e754e19ce5d6a06c71c20689ce3d.tar.gz"
  version "2.0"
  sha256 "dae8ed99eebb7593b43013f6532d772b12dfecd55548d2673f2dfd0163f6d2b9"
  license "MIT"
  revision 1

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "73cff990d70323b12e517f7dfddbf94a71f8ce53dff9c47e3b4612c57c773d2c"
    sha256 cellar: :any_skip_relocation, ventura:       "4dbe393d28121919a9e41e79bc7424e9523a7c723fd71bb369c1a2b7a4aa8a9f"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "ac30d9966b941fb9c5a022fb6a1b8e742d46369b25655e0aad5af9a3667e59e3"
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
