class Rum < Formula
  desc "Inverted index with additional information in posting lists"
  homepage "https://github.com/postgrespro/rum"
  url "https://github.com/postgrespro/rum/archive/refs/tags/1.3.15.tar.gz"
  sha256 "e79b3a67df9821bc0d86fd463dac7249f1729d9dd04f77db767e2815098247b8"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "53774197572412303dddd89ac8974ac00167a19781d9ce2795eb1539e1b49f5f"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "40b2406a8f126c57d72d7ad3cebd19561b676eaef28faca278a55bce3ecc4587"
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
      ENV["USE_PGXS"] = "1"
      system "make", "clean", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"
      system "make", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"

      mkdir_p lib/neon_postgres.name/v
      mv "rum.#{neon_postgres.dlsuffix(v)}", lib/neon_postgres.name/v

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
