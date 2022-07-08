class Neon < Formula
  desc "Serverless open source alternative to AWS Aurora Postgres"
  homepage "https://neon.tech"
  url "https://github.com/neondatabase/neon.git",
    revision: "00c26ff3a3bebcc4f757ee6b475d61e29acf6dbd"
  version "20220708"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  bottle do
    root_url "https://github.com/bayandin/homebrew-tap/releases/download/neon-20220708"
    sha256 monterey:     "1968af8899e6a19e694ecc4eab22306cf07212e8b9d9f3edcf3a8ffdb53ff71a"
    sha256 big_sur:      "fbcbf83112aa0096414648410c03a331a1791338431f81d6857e0ef93dabd80b"
    sha256 catalina:     "a9b84f84d11fda299bc3c6c3d1e132a663715303cb68ac8d87852c5e138279b4"
    sha256 x86_64_linux: "b36bc045de192744ca928c68016bcfeaa948f1fd764a0c2680bb9d7bf65e48cb"
  end

  depends_on "rust" => :build
  depends_on "libpq" => :test
  depends_on "etcd"
  depends_on "openssl@3"
  depends_on "protobuf"
  depends_on "readline"

  uses_from_macos "bison" => :build
  uses_from_macos "flex" => :build

  on_linux do
    depends_on "libseccomp"
  end

  # Make Postgres directory configurable
  patch :DATA

  def install
    pg_distrib_dir = libexec/"postgres"
    env = { POSTGRES_DISTRIB_DIR: pg_distrib_dir }

    inreplace "libs/postgres_ffi/build.rs", ".clang_arg(\"-I../../tmp_install",
                                            ".clang_arg(\"-I#{pg_distrib_dir}"

    with_env(env.merge(BUILD_TYPE: "release")) do
      system "make"
    end

    %w[
      dump_layerfile
      safekeeper
      proxy
      compute_ctl
      neon_local
      wal_generate
      pageserver
      update_metadata
    ].each { |f| bin.install "target/release/#{f}" }
    bin.env_script_all_files libexec/"bin", env.merge(NEON_REPO_DIR: "${NEON_REPO_DIR:-#{var}/neon}")

    (pg_distrib_dir/"build").rmtree

    if OS.linux?
      inreplace pg_distrib_dir/"lib/pgxs/src/Makefile.global",
                "LD = #{HOMEBREW_PREFIX}/Homebrew/Library/Homebrew/shims/linux/super/ld",
                "LD = #{HOMEBREW_PREFIX}/bin/ld"
    end
  end

  def post_install
    unless (var/"neon").exist?
      system bin/"neon_local", "init"
      inreplace %W[#{var}/neon/config #{var}/neon/pageserver.toml], libexec, opt_libexec
    end
  end

  test do
    ENV["NEON_REPO_DIR"] = testpath/"neon"
    system bin/"neon_local", "init"

    sk_http_port = free_port
    sk_pg_port = free_port
    ps_http_port = free_port
    ps_pg_port = free_port
    etcd_port = free_port

    inreplace testpath/"neon/config" do |s|
      s.gsub! "http_port = 7676", "http_port = #{sk_http_port}"
      s.gsub! "pg_port = 5454", "pg_port = #{sk_pg_port}"
      s.gsub! "listen_http_addr = '127.0.0.1:9898'", "listen_http_addr = '127.0.0.1:#{ps_http_port}'"
      s.gsub! "listen_pg_addr = '127.0.0.1:64000'", "listen_pg_addr = '127.0.0.1:#{ps_pg_port}'"
      s.gsub! "broker_endpoints = ['http://localhost:2379/']", "broker_endpoints = ['http://localhost:#{etcd_port}/']"
    end

    inreplace testpath/"neon/pageserver.toml" do |s|
      s.gsub! "listen_http_addr ='127.0.0.1:9898'", "listen_http_addr = '127.0.0.1:#{ps_http_port}'"
      s.gsub! "listen_pg_addr ='127.0.0.1:64000'", "listen_pg_addr = '127.0.0.1:#{ps_pg_port}'"
      s.gsub! "broker_endpoints =['http://localhost:2379/']", "broker_endpoints = ['http://localhost:#{etcd_port}/']"
    end

    system bin/"neon_local", "start"
    system bin/"neon_local", "pg", "start", "main"

    test_command = %W[
      #{Formula["libpq"].opt_bin}/psql
      --port=55432
      --host=127.0.0.1
      --username=cloud_admin
      --dbname=postgres
      --tuples-only
      --command="SELECT 40 + 2"
    ].join(" ")

    output = shell_output test_command
    assert_equal "42", output.strip
  ensure
    system bin/"neon_local", "stop"
  end
end

__END__
diff --git a/Makefile b/Makefile
index 50e2c8ab..fbed514b 100644
--- a/Makefile
+++ b/Makefile
@@ -1,3 +1,6 @@
+POSTGRES_DISTRIB_DIR ?= tmp_install
+PROJECT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
+
 # Seccomp BPF is only available for Linux
 UNAME_S := $(shell uname -s)
 ifeq ($(UNAME_S),Linux)
@@ -55,55 +58,55 @@ zenith: postgres-headers
 	$(CARGO_CMD_PREFIX) cargo build $(CARGO_BUILD_FLAGS)

 ### PostgreSQL parts
-tmp_install/build/config.status:
+$(POSTGRES_DISTRIB_DIR)/build/config.status:
 	+@echo "Configuring postgres build"
-	mkdir -p tmp_install/build
-	(cd tmp_install/build && \
-	../../vendor/postgres/configure CFLAGS='$(PG_CFLAGS)' \
+	mkdir -p $(POSTGRES_DISTRIB_DIR)/build
+	(cd $(POSTGRES_DISTRIB_DIR)/build && \
+	$(PROJECT_DIR)/vendor/postgres/configure CFLAGS='$(PG_CFLAGS)' \
 		$(PG_CONFIGURE_OPTS) \
 		$(SECCOMP) \
-		--prefix=$(abspath tmp_install) > configure.log)
+		--prefix=$(abspath $(POSTGRES_DISTRIB_DIR)) > configure.log)

 # nicer alias for running 'configure'
 .PHONY: postgres-configure
-postgres-configure: tmp_install/build/config.status
+postgres-configure: $(POSTGRES_DISTRIB_DIR)/build/config.status

-# Install the PostgreSQL header files into tmp_install/include
+# Install the PostgreSQL header files into $(POSTGRES_DISTRIB_DIR)/include
 .PHONY: postgres-headers
 postgres-headers: postgres-configure
 	+@echo "Installing PostgreSQL headers"
-	$(MAKE) -C tmp_install/build/src/include MAKELEVEL=0 install
+	$(MAKE) -C $(POSTGRES_DISTRIB_DIR)/build/src/include MAKELEVEL=0 install

 # Compile and install PostgreSQL and contrib/neon
 .PHONY: postgres
 postgres: postgres-configure \
 		  postgres-headers # to prevent `make install` conflicts with zenith's `postgres-headers`
 	+@echo "Compiling PostgreSQL"
-	$(MAKE) -C tmp_install/build MAKELEVEL=0 install
+	$(MAKE) -C $(POSTGRES_DISTRIB_DIR)/build MAKELEVEL=0 install
 	+@echo "Compiling contrib/neon"
-	$(MAKE) -C tmp_install/build/contrib/neon install
+	$(MAKE) -C $(POSTGRES_DISTRIB_DIR)/build/contrib/neon install
 	+@echo "Compiling contrib/neon_test_utils"
-	$(MAKE) -C tmp_install/build/contrib/neon_test_utils install
+	$(MAKE) -C $(POSTGRES_DISTRIB_DIR)/build/contrib/neon_test_utils install
 	+@echo "Compiling pg_buffercache"
-	$(MAKE) -C tmp_install/build/contrib/pg_buffercache install
+	$(MAKE) -C $(POSTGRES_DISTRIB_DIR)/build/contrib/pg_buffercache install
 	+@echo "Compiling pageinspect"
-	$(MAKE) -C tmp_install/build/contrib/pageinspect install
+	$(MAKE) -C $(POSTGRES_DISTRIB_DIR)/build/contrib/pageinspect install


 .PHONY: postgres-clean
 postgres-clean:
-	$(MAKE) -C tmp_install/build MAKELEVEL=0 clean
+	$(MAKE) -C $(POSTGRES_DISTRIB_DIR)/build MAKELEVEL=0 clean

 # This doesn't remove the effects of 'configure'.
 .PHONY: clean
 clean:
-	cd tmp_install/build && $(MAKE) clean
+	cd $(POSTGRES_DISTRIB_DIR)/build && $(MAKE) clean
 	$(CARGO_CMD_PREFIX) cargo clean

 # This removes everything
 .PHONY: distclean
 distclean:
-	rm -rf tmp_install
+	rm -rf $(POSTGRES_DISTRIB_DIR)
 	$(CARGO_CMD_PREFIX) cargo clean

 .PHONY: fmt
