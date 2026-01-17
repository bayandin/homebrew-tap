class PostgresqlHll < Formula
  desc "PostgreSQL extension adding HyperLogLog data structures as a native data type"
  homepage "https://github.com/citusdata/postgresql-hll"
  url "https://github.com/citusdata/postgresql-hll/archive/refs/tags/v2.19.tar.gz"
  sha256 "d63d56522145f2d737e0d056c9cfdfe3e8b61008c12ca4c45bde7d9b942f9c46"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "62d2903d5aeb0e0fe49de1524aa9d4fc0c35c72a1840e0fc9160bf2a95fd2bb4"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "860a59d4de3c321d073a060d22e96de85586d85ab400924f3a386f175dcab94a"
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
