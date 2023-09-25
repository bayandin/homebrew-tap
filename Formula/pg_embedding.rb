class PgEmbedding < Formula
  desc "HNSW algorithm for vector similarity search in PostgreSQL"
  homepage "https://github.com/neondatabase/pg_embedding"
  url "https://github.com/neondatabase/pg_embedding/archive/refs/tags/0.3.6.tar.gz"
  sha256 "b2e2b359335d26987778c7fae0c9bcc8ebc3530fc214113be1ddbc8a136e52ac"
  license "Apache-2.0"
  revision 1

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "4a651c6400fc2bb6f6f72267bdc2d2dbfc7e2504e5083ba1c5efca16848b50ce"
    sha256 cellar: :any_skip_relocation, ventura:       "6a68b460068b769952f74bcbc893ecb25144313f599f1f9e758f34b07004b0aa"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "ee9060d71403fee51c983904ba768a6378db4c3d4895b4d49678fa92898df4c5"
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
      mv "embedding.#{dlsuffix}", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "embedding.control", share/neon_postgres.name/v/"extension"
      cp Dir["embedding--*.sql"], share/neon_postgres.name/v/"extension"
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
