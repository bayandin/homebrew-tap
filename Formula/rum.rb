class Rum < Formula
  desc "Inverted index with additional information in posting lists"
  homepage "https://github.com/postgrespro/rum"
  url "https://github.com/postgrespro/rum/archive/refs/tags/1.3.13.tar.gz"
  sha256 "6ab370532c965568df6210bd844ac6ba649f53055e48243525b0b7e5c4d69a7d"
  license "PostgreSQL"
  revision 1

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "41d0a468cb50081f49e57b69d9f81ced2521f60a247cb724c52a6e1a30ae2062"
    sha256 cellar: :any_skip_relocation, ventura:       "badf962d9c7f50b2e07c639c5f72b2a11dbbd00d12c5f666f31e0020faf9cddf"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "1e25cdcb1d2ae28d856ee40f3acb75d4e91eeb24ce5124aff9800d0e6299809e"
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

      ENV["USE_PGXS"] = "1"
      system "make", "clean", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"
      system "make", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"

      mkdir_p lib/neon_postgres.name/v
      mv "rum.#{dlsuffix}", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "rum.control", share/neon_postgres.name/v/"extension"
      cp Dir["rum--*.sql"], share/neon_postgres.name/v/"extension"
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
          CREATE EXTENSION rum;
          CREATE TABLE query (q tsquery, tag text);

          INSERT INTO query VALUES ('supernova & star', 'sn'),
              ('black', 'color'),
              ('big & bang & black & hole', 'bang'),
              ('spiral & galaxy', 'shape'),
              ('black & hole', 'color');

          CREATE INDEX query_idx ON query USING rum(q);
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
