class Prefix < Formula
  desc "Module PostgreSQL for Prefix Matching"
  homepage "https://github.com/dimitri/prefix"
  url "https://github.com/dimitri/prefix/archive/refs/tags/v1.2.10.tar.gz"
  sha256 "4342f251432a5f6fb05b8597139d3ccde8dcf87e8ca1498e7ee931ca057a8575"
  license "PostgreSQL"
  revision 1

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "21c708008a7f019d845db8d54e49e8a40ff2268a42357bdeed309f5a674a352e"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "3f1cae543ca16806aa913dc2efc8eaa8aa682fe075032a7239585fc78ff6b553"
    sha256 cellar: :any_skip_relocation, ventura:       "3d4c083811658a292653327dc80ee65955d3e25f86481f74446263b5a732f609"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "087ff1731bd7a8bb081dc84c23c991970cfcfa2c233c925b5d765c724d84d853"
  end

  depends_on "bayandin/tap/neon-postgres"

  resource "homebrew-prefixes.fr.csv" do
    url "https://raw.githubusercontent.com/dimitri/prefix/v1.2.10/prefixes.fr.csv"
    sha256 "3d36e30730c8a34274e39353d94dc6c1dbbea0b66e896f8f953462f5689042a9"
  end

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
      mv "prefix.#{neon_postgres.dlsuffix(v)}", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "prefix.control", share/neon_postgres.name/v/"extension"
      cp Dir["prefix--*.sql"], share/neon_postgres.name/v/"extension"
    end
  end

  test do
    testpath.install resource("homebrew-prefixes.fr.csv")

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
          CREATE EXTENSION prefix;

          CREATE TABLE prefixes (
            prefix    prefix_range PRIMARY KEY,
            name      TEXT NOT NULL,
            shortname TEXT,
            status    CHAR DEFAULT 'S',

            CHECK( STATUS IN ('S', 'R') )
          );
          COMMENT ON COLUMN prefixes.status IS 'S:   - R: reserved';
        SQL
        system psql, "-p", port.to_s, "-c", "\\copy prefixes FROM 'prefixes.fr.csv'
                                              WITH delimiter ';' csv quote '\"'", "postgres"
        system psql, "-p", port.to_s, "-c", <<~SQL, "postgres"
          CREATE INDEX idx_prefix ON prefixes USING gist(prefix);
          SELECT '123'::prefix_range @> '123456';
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
