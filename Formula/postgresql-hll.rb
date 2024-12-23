class PostgresqlHll < Formula
  desc "PostgreSQL extension adding HyperLogLog data structures as a native data type"
  homepage "https://github.com/citusdata/postgresql-hll"
  url "https://github.com/citusdata/postgresql-hll/archive/refs/tags/v2.18.tar.gz"
  sha256 "e2f55a6f4c4ab95ee4f1b4a2b73280258c5136b161fe9d059559556079694f0e"
  license "Apache-2.0"
  revision 2

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "72882187f7aa6578509cd38c0d8efbc6e118817feac9fbceab42b2b5387bb295"
    sha256 cellar: :any_skip_relocation, ventura:       "b55309874b50413664a391ba95811ae5452c0d24bde6559012dbbfaba88a2a1a"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "3f5098ea724a4bdc2f103a71c5d9c00b4e680f875f703fd9823cc0d31e985a28"
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
