class Hypopg < Formula
  desc "Hypothetical Indexes for PostgreSQL"
  homepage "https://hypopg.readthedocs.io"
  url "https://github.com/HypoPG/hypopg/archive/refs/tags/1.4.1.tar.gz"
  sha256 "9afe6357fd389d8d33fad81703038ce520b09275ec00153c6c89282bcdedd6bc"
  license "PostgreSQL"
  revision 1

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "409d5494943093655831a6366811c00ccd436fc8e6d6c1be890e7d719a530b27"
    sha256 cellar: :any_skip_relocation, ventura:      "428259c200716d7d888687377fb3c03881d68d9ffacfcade431f80c14555159f"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "bf9cecb1abadbd2d5dd6d8f954ed0a98f04dcc273e139f490d75247757ff2ad8"
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
