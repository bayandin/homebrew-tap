class Rum < Formula
  desc "Inverted index with additional information in posting lists"
  homepage "https://github.com/postgrespro/rum"
  url "https://github.com/postgrespro/rum/archive/refs/tags/1.3.15.tar.gz"
  sha256 "e79b3a67df9821bc0d86fd463dac7249f1729d9dd04f77db767e2815098247b8"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "c4ef78671841588b470c8ec5729564d8947951ebb5d34f075cadb1f8584f3420"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "d7f1da4d79f9d8e35719f4509be09c5db2f3f25089dd421a71dcd4c5003babdc"
    sha256 cellar: :any_skip_relocation, ventura:       "f660ffd1d1963265337b2b82eba054bb3cea53afaa93294ca9fb0d006189780c"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "21487ad1d6390ee00b5854a94f5f6db62be6ac36f265a5bfd2b477d9be528248"
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
