class Pgvector < Formula
  desc "Open-source vector similarity search for Postgres"
  homepage "https://github.com/pgvector/pgvector"
  url "https://github.com/pgvector/pgvector/archive/refs/tags/v0.5.1.tar.gz"
  sha256 "cc7a8e034a96e30a819911ac79d32f6bc47bdd1aa2de4d7d4904e26b83209dc8"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "7a764bdd41b9921ceeb10d90e023c8f4dfeced2c752014f9ec7d959b331ab517"
    sha256 cellar: :any_skip_relocation, ventura:       "afe8ee24a05d4053eec17140ee92db5308de03592ac9879e2e1d427b979d5516"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "225a060539bd7dad372100d98165ea43e25834ad36025e13fa2de758ce1f060b"
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
      # Ref https://github.com/postgres/postgres/commit/b55f62abb2c2e07dfae99e19a2b3d7ca9e58dc1a
      dlsuffix = (OS.linux? || "v14 v15".include?(v)) ? "so" : "dylib"

      ENV["PG_CONFIG"] = neon_postgres.pg_bin_for(v)/"pg_config"
      system "make", "clean"
      system "make"

      mkdir_p lib/neon_postgres.name/v
      mv "vector.#{dlsuffix}", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "vector.control", share/neon_postgres.name/v/"extension"
      cp Dir["sql/vector--*.sql"], share/neon_postgres.name/v/"extension"
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
          CREATE EXTENSION vector;
          CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(3));
          INSERT INTO items (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');
          CREATE INDEX ON items USING ivfflat (embedding vector_l2_ops) WITH (lists = 100);
          SELECT * FROM items ORDER BY embedding <-> '[3,1,2]' LIMIT 5;
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
