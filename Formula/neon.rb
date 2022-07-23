class Neon < Formula
  desc "Serverless open source alternative to AWS Aurora Postgres"
  homepage "https://neon.tech"
  url "https://github.com/neondatabase/neon.git",
    revision: "39c59b8df5069efb9364280cf64b8f9ecf4241b3"
  version "20220723"
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

  def install
    pg_distrib_dir = libexec/"postgres"

    with_env(POSTGRES_INSTALL_DIR: pg_distrib_dir, BUILD_TYPE: "release") do
      system "make", "postgres"
      system "make", "zenith"
    end

    %w[
      dump_layerfile
      safekeeper
      proxy
      compute_ctl
      neon_local
      wal_craft
      pageserver
      update_metadata
    ].each { |f| bin.install "target/release/#{f}" }
    bin.env_script_all_files libexec/"bin", POSTGRES_DISTRIB_DIR: pg_distrib_dir,
                                            NEON_REPO_DIR:        "${NEON_REPO_DIR:-#{var}/neon}"

    (pg_distrib_dir/"build").rmtree # Remove after https://github.com/neondatabase/neon/pull/2127

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
