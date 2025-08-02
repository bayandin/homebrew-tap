class Hypopg < Formula
  desc "Hypothetical Indexes for PostgreSQL"
  homepage "https://hypopg.readthedocs.io"
  url "https://github.com/HypoPG/hypopg/archive/refs/tags/1.4.2.tar.gz"
  sha256 "30596ca3d71b33af53326cdf27ed9fc794dc6db33864c531fde1e48c1bf7de7d"
  license "PostgreSQL"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "b16748cb57867cbdaca8b42a633cc2c1cbf78bab3ea07d916784817f8f3130c0"
    sha256 cellar: :any_skip_relocation, ventura:       "8ce5a9926a2ff3c5d45e8825e16984e12b0aaf3f35f4c38ad8b9478a46d8fe1d"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "1e091a03e0d97bfb496c1268847c095d0488675182c0cd1aa51bdab252e38e14"
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
      ENV["PG_CONFIG"] = neon_postgres.pg_bin_for(v)/"pg_config"
      system "make", "clean"
      system "make"

      mkdir_p lib/neon_postgres.name/v
      mv "hypopg.#{neon_postgres.dlsuffix(v)}", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "hypopg.control", share/neon_postgres.name/v/"extension"
      cp Dir["hypopg--*.sql"], share/neon_postgres.name/v/"extension"
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
          CREATE EXTENSION hypopg;
          SELECT * FROM hypopg()
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
