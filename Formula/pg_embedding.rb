class PgEmbedding < Formula
  desc "HNSW algorithm for vector similarity search in PostgreSQL"
  homepage "https://github.com/neondatabase/pg_embedding"
  url "https://github.com/neondatabase/pg_embedding/archive/refs/tags/0.3.5.tar.gz"
  sha256 "0e95b27b8b6196e2cf0a0c9ec143fe2219b82e54c5bb4ee064e76398cbe69ae9"
  license "Apache-2.0"
  revision 1

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "65bdc70c835fc6551b621e1b41c7b65528eb5b5590ece6053d7302b304708185"
    sha256 cellar: :any_skip_relocation, ventura:       "3bb4b10c2d58d8cc58fd6697b5840e593f46fda85ccd05b19409cf586331abd1"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "9ddb61d28629128ceced890b169f1efc3f048a1629fbe45246df5dfa92286946"
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
