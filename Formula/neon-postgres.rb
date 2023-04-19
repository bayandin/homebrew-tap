class NeonPostgres < Formula
  desc "Serverless Postgres"
  homepage "https://neon.tech"
  url "https://github.com/neondatabase/neon.git",
    revision: "02b28ae0b107f0fa2cc5b650d36de04bd7bc78e7"
  version "20230418"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  depends_on "rust" => :build
  depends_on "libpq" => :test
  depends_on "openssl@3"
  depends_on "protobuf"
  depends_on "readline"
  uses_from_macos "llvm" => :build

  on_linux do
    depends_on "libseccomp"
  end

  def install
    pg_install_dir = libexec/"postgres"

    ENV["POSTGRES_INSTALL_DIR"] = pg_install_dir
    ENV["BUILD_TYPE"] = "release"
    ENV["OPENSSL_PREFIX"] = Formula["openssl@3"].opt_prefix

    system "make", "postgres"
    system "make", "neon-pg-ext"
    system "make", "neon"

    %w[
      compute_ctl
      draw_timeline_dir
      layer_map_analyzer
      neon_local
      pageserver
      pageserver_binutils
      proxy
      safekeeper
      storage_broker
      trace
      wal_craft
    ].each { |f| bin.install "target/release/#{f}" }
    bin.env_script_all_files libexec/"bin", POSTGRES_DISTRIB_DIR: pg_install_dir,
                                            NEON_REPO_DIR:        "${NEON_REPO_DIR:-#{var}/neon}"

    (pg_install_dir/"build").rmtree

    if OS.linux?
      %w[v14 v15].each do |v|
        inreplace pg_install_dir/v/"lib/pgxs/src/Makefile.global",
                  "LD = #{HOMEBREW_PREFIX}/Homebrew/Library/Homebrew/shims/linux/super/ld",
                  "LD = #{HOMEBREW_PREFIX}/bin/ld"
      end
    end
  end

  def post_install
    unless (var/"neon").exist?
      system bin/"neon_local", "init"
      inreplace %W[#{var}/neon/config #{var}/neon/pageserver.toml], libexec, opt_libexec
    end
  end

  test do
    neon_repo_dir = testpath/"neon"
    ENV["NEON_REPO_DIR"] = neon_repo_dir
    ENV.prepend_path "PATH", Formula["openssl@3"].opt_bin

    system bin/"neon_local", "init"

    sk_http_port = free_port
    sk_pg_port = free_port
    ps_http_port = free_port
    ps_pg_port = free_port
    broker_port = free_port

    inreplace neon_repo_dir/"config" do |s|
      s.gsub! "http_port = 7676", "http_port = #{sk_http_port}"
      s.gsub! "pg_port = 5454", "pg_port = #{sk_pg_port}"
      s.gsub! "listen_http_addr = \"127.0.0.1:9898\"", "listen_http_addr = \"127.0.0.1:#{ps_http_port}\""
      s.gsub! "listen_pg_addr = \"127.0.0.1:64000\"", "listen_pg_addr = \"127.0.0.1:#{ps_pg_port}\""
      s.gsub! "listen_addr = \"127.0.0.1:50051\"", "listen_addr = \"127.0.0.1:#{broker_port}\""
    end

    inreplace neon_repo_dir/"pageserver.toml" do |s|
      s.gsub! "listen_http_addr ='127.0.0.1:9898'", "listen_http_addr = \"127.0.0.1:#{ps_http_port}\""
      s.gsub! "listen_pg_addr ='127.0.0.1:64000'", "listen_pg_addr = \"127.0.0.1:#{ps_pg_port}\""
      s.gsub! "broker_endpoint ='http://127.0.0.1:50051/'", "broker_endpoint = \"http://127.0.0.1:#{broker_port}/\""
    end

    system bin/"neon_local", "start"
    system bin/"neon_local", "tenant", "create", "--set-default"
    system bin/"neon_local", "endpoint", "start", "main"

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
