class PostgresqlHll < Formula
  desc "PostgreSQL extension adding HyperLogLog data structures as a native data type"
  homepage "https://github.com/citusdata/postgresql-hll"
  url "https://github.com/citusdata/postgresql-hll/archive/refs/tags/v2.19.tar.gz"
  sha256 "d63d56522145f2d737e0d056c9cfdfe3e8b61008c12ca4c45bde7d9b942f9c46"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "faa178bef91a0c2817a13c3eec3f75edb39ed6a1b5cff72c77eb91479deb658d"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "b68bf292523bd033cbbd7e6ab5d07d1272e22b2e63038a9eece9f804ecabfc07"
    sha256 cellar: :any_skip_relocation, ventura:       "7326ceb01d156fe000302a6fab6d156f5b2264d62bb9ce6003d50ea45a571b30"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "8377cac766ba9e1d7dc477416b0d53eabdf95c46e21ee97b3b7fbe979a2744df"
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
      mv "hll.#{neon_postgres.dlsuffix(v)}", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "hll.control", share/neon_postgres.name/v/"extension"
      cp Dir["hll--*.sql"], share/neon_postgres.name/v/"extension"
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
          CREATE EXTENSION hll;
          CREATE TABLE helloworld (id integer, set hll);
          INSERT INTO helloworld(id, set) VALUES (1, hll_empty());
          UPDATE helloworld SET set = hll_add(set, hll_hash_integer(12345)) WHERE id = 1;
          UPDATE helloworld SET set = hll_add(set, hll_hash_text('hello world')) WHERE id = 1;
          SELECT hll_cardinality(set) FROM helloworld WHERE id = 1;
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
