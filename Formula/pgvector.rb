class Pgvector < Formula
  desc "Open-source vector similarity search for Postgres"
  homepage "https://github.com/pgvector/pgvector"
  url "https://github.com/pgvector/pgvector/archive/refs/tags/v0.8.0.tar.gz"
  sha256 "867a2c328d4928a5a9d6f052cd3bc78c7d60228a9b914ad32aa3db88e9de27b0"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "cc89ca58eac428b3bd23317c5d123079b4bdf900dbbc47eee43915bcdb20f9fb"
    sha256 cellar: :any_skip_relocation, ventura:      "97366238bbf3bf9d9c70b5931426546a2ffa7f3c2d491bd91f8eed429be7e061"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "275b087b85a0b3f137fd5385b07116804620bafc2c3e976ae2effb0375e2c3f0"
  end

  depends_on "bayandin/tap/neon-postgres"

  patch :DATA

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
      mv "vector.#{neon_postgres.dlsuffix(v)}", lib/neon_postgres.name/v

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
diff --git a/src/hnswbuild.c b/src/hnswbuild.c
index dcfb2bd..d5189ee 100644
--- a/src/hnswbuild.c
+++ b/src/hnswbuild.c
@@ -860,9 +860,17 @@ HnswParallelBuildMain(dsm_segment *seg, shm_toc *toc)

 	hnswarea = shm_toc_lookup(toc, PARALLEL_KEY_HNSW_AREA, false);

+#ifdef NEON_SMGR
+	smgr_start_unlogged_build(RelationGetSmgr(indexRel));
+#endif
+
 	/* Perform inserts */
 	HnswParallelScanAndInsert(heapRel, indexRel, hnswshared, hnswarea, false);

+#ifdef NEON_SMGR
+	smgr_finish_unlogged_build_phase_1(RelationGetSmgr(indexRel));
+#endif
+
 	/* Close relations within worker */
 	index_close(indexRel, indexLockmode);
 	table_close(heapRel, heapLockmode);
@@ -1117,12 +1125,38 @@ BuildIndex(Relation heap, Relation index, IndexInfo *indexInfo,
 	SeedRandom(42);
 #endif

+#ifdef NEON_SMGR
+	smgr_start_unlogged_build(RelationGetSmgr(index));
+#endif
+
 	InitBuildState(buildstate, heap, index, indexInfo, forkNum);

 	BuildGraph(buildstate, forkNum);

-	if (RelationNeedsWAL(index) || forkNum == INIT_FORKNUM)
+#ifdef NEON_SMGR
+	smgr_finish_unlogged_build_phase_1(RelationGetSmgr(index));
+#endif
+
+	if (RelationNeedsWAL(index) || forkNum == INIT_FORKNUM) {
 		log_newpage_range(index, forkNum, 0, RelationGetNumberOfBlocksInFork(index, forkNum), true);
+#ifdef NEON_SMGR
+		{
+#if PG_VERSION_NUM >= 160000
+			RelFileLocator rlocator = RelationGetSmgr(index)->smgr_rlocator.locator;
+#else
+			RelFileNode rlocator = RelationGetSmgr(index)->smgr_rnode.node;
+#endif
+
+			SetLastWrittenLSNForBlockRange(XactLastRecEnd, rlocator,
+									   MAIN_FORKNUM, 0, RelationGetNumberOfBlocks(index));
+			SetLastWrittenLSNForRelation(XactLastRecEnd, rlocator, MAIN_FORKNUM);
+		}
+#endif
+	}
+
+#ifdef NEON_SMGR
+	smgr_end_unlogged_build(RelationGetSmgr(index));
+#endif

 	FreeBuildState(buildstate);
 }
