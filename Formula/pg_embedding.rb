class PgEmbedding < Formula
  desc "HNSW algorithm for vector similarity search in PostgreSQL"
  homepage "https://github.com/neondatabase/pg_embedding"
  url "https://github.com/neondatabase/pg_embedding/archive/eeb3ba7c3a60c95b2604dd543c64b2f1bb4a3703.tar.gz"
  version "0.1.0"
  sha256 "030846df723652f99a8689ce63b66fa0c23477a7fd723533ab8a6b28ab70730f"
  license "Apache-2.0"
  revision 1

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "a01a63954611801434a5648d7f6251ef3de9b3117a684ee463bfaa0755739b4a"
    sha256 cellar: :any_skip_relocation, ventura:       "cdce18baee77a1d3b0ba14a982932c687c39c1c33be2f182bc61a8e070c81350"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "c9a5317c576ad38b6c3f9189a1af59a0968b77b3c15ca8eec777fa62e01bddc4"
  end

  depends_on "bayandin/tap/neon-postgres"

  def pg_versions
    %w[v14 v15]
  end

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def install
    pg_versions.each do |v|
      system "make", "PG_CONFIG=#{neon_postgres.opt_libexec/v}/bin/pg_config"

      mkdir_p lib/neon_postgres.name/v
      mv "embedding.so", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "embedding.control", share/neon_postgres.name/v/"extension"
      cp Dir["embedding--*.sql"], share/neon_postgres.name/v/"extension"

      rm_f Dir["*.o"]
    end
  end

  test do
    pg_versions.each do |v|
      pg_ctl = neon_postgres.opt_libexec/v/"bin/pg_ctl"
      psql = neon_postgres.opt_libexec/v/"bin/psql"
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
          CREATE INDEX ON documents USING hnsw(embedding) WITH (maxelements=1000, dims=3, m=8);
          SELECT id FROM documents ORDER BY embedding <-> array[1.1, 2.2, 3.3] LIMIT 1;
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end