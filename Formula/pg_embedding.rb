class PgEmbedding < Formula
  desc "HNSW algorithm for vector similarity search in PostgreSQL"
  homepage "https://github.com/neondatabase/pg_embedding"
  url "https://github.com/neondatabase/pg_embedding/archive/refs/tags/0.3.6.tar.gz"
  sha256 "b2e2b359335d26987778c7fae0c9bcc8ebc3530fc214113be1ddbc8a136e52ac"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "0c44f2821febe488b34d2cd669180e488ea4f3320c2c5372f787cb104d7b245b"
    sha256 cellar: :any_skip_relocation, ventura:       "b03ca7f9622372270b6cdb7370413645359c226ffb7e30e24ddab20cd1936091"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "6cd1a66ed92655ba1840e3cefb7cb1bd6c9d11ebe5201d14ea70ab52d08e559b"
  end

  depends_on "bayandin/tap/neon-postgres"

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def install
    neon_postgres.pg_versions.each do |v|
      ENV["PG_CONFIG"] = neon_postgres.pg_bin_for(v)/"pg_config"
      system "make", "clean"
      system "make"

      mkdir_p lib/neon_postgres.name/v
      mv "embedding.so", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "embedding.control", share/neon_postgres.name/v/"extension"
      cp Dir["embedding--*.sql"], share/neon_postgres.name/v/"extension"
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
          CREATE EXTENSION embedding;
          CREATE TABLE documents(id INTEGER, embedding REAL[]);
          INSERT INTO documents(id, embedding) VALUES (1, '{1.1, 2.2, 3.3}'),(2, '{4.4, 5.5, 6.6}');
          CREATE INDEX ON documents USING hnsw(embedding) WITH (dims=3, m=8);
          SELECT id FROM documents ORDER BY embedding <-> array[1.1, 2.2, 3.3] LIMIT 1;
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
