class Rum < Formula
  desc "Inverted index with additional information in posting lists"
  homepage "https://github.com/postgrespro/rum"
  url "https://github.com/postgrespro/rum/archive/refs/tags/1.3.13.tar.gz"
  sha256 "6ab370532c965568df6210bd844ac6ba649f53055e48243525b0b7e5c4d69a7d"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "20042d64c4616e3859c2eaf936d81ed0b29b313c80b1d107270a85bd993a5c87"
    sha256 cellar: :any_skip_relocation, ventura:       "33c71fc86a6275d4ef794f351dabf9f8b15f00e4c3311ee6cd89c6880a155913"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "2066de3809d542ec6c4932a9d51ea672f9f923847bd93e692123a43376bae651"
  end

  depends_on "bayandin/tap/neon-postgres"

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def install
    neon_postgres.pg_versions.each do |v|
      ENV["USE_PGXS"] = "1"
      system "make", "clean", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"
      system "make", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"

      mkdir_p lib/neon_postgres.name/v
      mv "rum.so", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "rum.control", share/neon_postgres.name/v/"extension"
      cp Dir["rum--*.sql"], share/neon_postgres.name/v/"extension"
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
