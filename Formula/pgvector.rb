class Pgvector < Formula
  desc "Open-source vector similarity search for Postgres"
  homepage "https://github.com/pgvector/pgvector"
  url "https://github.com/pgvector/pgvector/archive/refs/tags/v0.7.2.tar.gz"
  sha256 "617fba855c9bcb41a2a9bc78a78567fd2e147c72afd5bf9d37b31b9591632b30"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "31c185bcfe47acf4a839339aaca7a6457fa29d41e4986d13a479608d01389715"
    sha256 cellar: :any_skip_relocation, ventura:      "b1d50fbad5e2e0849725bb5c6531272e04a9aa1617039704c487bc83e7a50e31"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "069f341d8d8d0ce107c5673c4b3223a445496b4ad5c4c0de0f0076d357eea64e"
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
