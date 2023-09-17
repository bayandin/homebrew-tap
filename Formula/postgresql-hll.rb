class PostgresqlHll < Formula
  desc "PostgreSQL extension adding HyperLogLog data structures as a native data type"
  homepage "https://github.com/citusdata/postgresql-hll"
  url "https://github.com/citusdata/postgresql-hll/archive/refs/tags/v2.18.tar.gz"
  sha256 "e2f55a6f4c4ab95ee4f1b4a2b73280258c5136b161fe9d059559556079694f0e"
  license "Apache-2.0"
  revision 1

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "9988a9e199ba0bd9c0b4dbcdf0963020ebf6049f101e632f845c906fe571d0f3"
    sha256 cellar: :any_skip_relocation, ventura:       "6b8fcdce074e6c4bd1f583cc910cb222536d8ad0ab8ba1b8d5a2c3c0a85ee3f1"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "f20416ed3c3dee9c38d1e5bb077363481f9b7ed15dbcfa7623ea618915467dfd"
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

      ENV["PG_CONFIG"] = neon_postgres.pg_bin_for(v)/"pg_config"
      system "make", "clean"
      system "make"

      mkdir_p lib/neon_postgres.name/v
      mv "hll.#{dlsuffix}", lib/neon_postgres.name/v

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
