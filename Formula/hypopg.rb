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
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "71912ba54e07431b16f1ee0ecccfed2bc7e5e44406d30e8873dac4b0d9a522b7"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "3af03fb671b6f9da7a15a816aecc0d0d71ddd221228925575c0b9a40dd314cb8"
    sha256 cellar: :any_skip_relocation, ventura:       "b908fb783037fded25575bd86da547248161cdae1a61a37699303404901685c8"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "b48615b47ba63f07716c0918bfcae4e0df8e4926ded197631cb2313d6280775a"
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
