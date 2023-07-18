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
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_ventura: "488097d1a821e857f20b823eeb758717c37b3cd7365d36ef244631b9ca06fa74"
    sha256 cellar: :any_skip_relocation, ventura:       "5ac0f4fc8c7eb1015370db05bcd2f208c4ed3c6794f959043564ea25afb4f927"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "a2f0e6dacb33b4833b9db745d7a5e1f997fa5952b1be9e9a63a63df42d6224c6"
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
      ENV["PG_CONFIG"] = neon_postgres.opt_libexec/v/"bin/pg_config"
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
