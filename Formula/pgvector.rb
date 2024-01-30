class Pgvector < Formula
  desc "Open-source vector similarity search for Postgres"
  homepage "https://github.com/pgvector/pgvector"
  url "https://github.com/pgvector/pgvector/archive/refs/tags/v0.6.0.tar.gz"
  sha256 "b0cf4ba1ab016335ac8fb1cada0d2106235889a194fffeece217c5bda90b2f19"
  license "PostgreSQL"
  revision 1

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "245da42a151bbb5d8cc520a41fb58a5ed5b03068c697e4228bd6eb83b457ff23"
    sha256 cellar: :any_skip_relocation, ventura:       "aadd2da02306d11d8a48186348a86ec489df9788e93a4e56eaa9adb41e0b288f"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "dbaf3436fe76552f8b80f860c0061e4efdb6dd4d1a1ad11440ab02df697fe1b2"
  end

  depends_on "bayandin/tap/neon-postgres"

  patch :DATA

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

__END__
From 5518a806a70e7f40d5054a762ccda7d5e6b0d31c Mon Sep 17 00:00:00 2001
From: Heikki Linnakangas <heikki.linnakangas@iki.fi>
Date: Tue, 30 Jan 2024 14:33:00 +0200
Subject: [PATCH] Make v0.6.0 work with Neon

Now that the WAL-logging happens as a separate step at the end of the
build, we need a few neon-specific hints to make it work.
---
 src/hnswbuild.c | 28 ++++++++++++++++++++++++++++
 1 file changed, 28 insertions(+)

diff --git a/src/hnswbuild.c b/src/hnswbuild.c
index 680789ba..41c5b709 100644
--- a/src/hnswbuild.c
+++ b/src/hnswbuild.c
@@ -1089,13 +1089,41 @@ BuildIndex(Relation heap, Relation index, IndexInfo *indexInfo,
 	SeedRandom(42);
 #endif

+#ifdef NEON_SMGR
+	smgr_start_unlogged_build(index->rd_smgr);
+#endif
+
 	InitBuildState(buildstate, heap, index, indexInfo, forkNum);

 	BuildGraph(buildstate, forkNum);

+#ifdef NEON_SMGR
+	smgr_finish_unlogged_build_phase_1(index->rd_smgr);
+#endif
+
 	if (RelationNeedsWAL(index))
+	{
 		log_newpage_range(index, forkNum, 0, RelationGetNumberOfBlocks(index), true);

+#ifdef NEON_SMGR
+		{
+#if PG_VERSION_NUM >= 160000
+			RelFileLocator rlocator = index->rd_smgr->smgr_rlocator.locator;
+#else
+			RelFileNode rlocator = index->rd_smgr->smgr_rnode.node;
+#endif
+
+			SetLastWrittenLSNForBlockRange(XactLastRecEnd, rlocator,
+										   MAIN_FORKNUM, 0, RelationGetNumberOfBlocks(index));
+			SetLastWrittenLSNForRelation(XactLastRecEnd, rlocator, MAIN_FORKNUM);
+		}
+#endif
+	}
+
+#ifdef NEON_SMGR
+	smgr_end_unlogged_build(index->rd_smgr);
+#endif
+
 	FreeBuildState(buildstate);
 }
