class H3Pg < Formula
  desc "PostgreSQL bindings for H3, a hierarchical hexagonal geospatial indexing system"
  homepage "https://github.com/zachasme/h3-pg"
  url "https://github.com/zachasme/h3-pg/archive/refs/tags/v4.1.3.tar.gz"
  sha256 "5c17f09a820859ffe949f847bebf1be98511fb8f1bd86f94932512c00479e324"
  license "Apache-2.0"
  revision 1

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_ventura: "6b6f876bf39d25149c014e58bfbc3732209664b9ca035d151911b1bea9c2fd76"
    sha256 cellar: :any,                 ventura:       "ceffb43854943f972c28596a24f3fb85ebfbd5eda691c8f6b8394875cb6af169"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "fa4a9129afdad4dd9560ac9529bfda65cb8c1bbfa923993cd9f871d93dedc3d0"
  end

  depends_on "cmake" => :build
  depends_on "bayandin/tap/neon-postgres"

  patch :DATA

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

      mkdir buildpath/"build-#{v}"

      cd buildpath/"build-#{v}" do
        system "cmake", "-DPostgreSQL_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config", "..", *std_cmake_args
        system "make"
        system "make", "install", "DESTDIR=#{buildpath}/stage-#{v}"
      end

      stage_dir = Pathname("stage-#{v}#{HOMEBREW_PREFIX}")
      mkdir_p lib/neon_postgres.name/v
      mv Dir[stage_dir/"lib"/neon_postgres.name/v/"*.#{dlsuffix}"], lib/neon_postgres.name/v

      from_ext_dir = stage_dir/"share"/neon_postgres.name/v/"extension"
      to_ext_dir = share/neon_postgres.name/v/"extension"

      mkdir_p to_ext_dir
      mv Dir[from_ext_dir/"*.control"], to_ext_dir
      mv Dir[from_ext_dir/"*--*.sql"], to_ext_dir
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
          CREATE EXTENSION h3;
          SELECT h3_lat_lng_to_cell(POINT('37.3615593,-122.0553238'), 5);
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end

__END__
diff --git a/cmake/AddPostgreSQLExtension.cmake b/cmake/AddPostgreSQLExtension.cmake
index 655cbc2..e316ad3 100644
--- a/cmake/AddPostgreSQLExtension.cmake
+++ b/cmake/AddPostgreSQLExtension.cmake
@@ -44,6 +44,12 @@ function(PostgreSQL_add_extension LIBRARY_NAME)
       PREFIX "" # Avoid lib* prefix on output file
     )

+    # Since Postgres 16, the shared library extension on macOS is `dylib`, not `so`.
+    # Ref https://github.com/postgres/postgres/commit/b55f62abb2c2e07dfae99e19a2b3d7ca9e58dc1a
+    if (APPLE AND ${PostgreSQL_VERSION_MAJOR} VERSION_GREATER_EQUAL "16")
+      set_target_properties (${LIBRARY_NAME} PROPERTIES SUFFIX ".dylib")
+    endif()
+
     # Install .so/.dll to pkglib-dir
     install(
       TARGETS ${LIBRARY_NAME}
