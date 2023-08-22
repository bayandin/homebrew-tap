class NeonLocal < Formula
  desc "CLI for running Neon locally"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon/archive/refs/tags/release-3756.tar.gz"
  sha256 "1a6d1469df36772a6ba74f850877c72864ab28a43a5e2aecae5374304c6faffa"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "d33498e928b245d3672abeba4a2113ec327ecbdb0e4c223905c694d52db49798"
    sha256 cellar: :any_skip_relocation, ventura:       "2c6d38d646bde589476ab492e8a19eae672a8e31a854ccb60f5e90cee21f2e92"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "7f04b9c4038f601c8f42be82f46d6680c7a46b9d85309d758c28c09cf8221a83"
  end

  depends_on "bayandin/tap/neon-extension"
  depends_on "bayandin/tap/neon-postgres"
  depends_on "bayandin/tap/neon-storage"

  def binaries
    %w[
      compute_ctl neon_local pagectl pageserver
      pg_sni_router proxy safekeeper
      storage_broker trace wal_craft
    ]
  end

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def neon_storage
    Formula["bayandin/tap/neon-storage"]
  end

  def install
    binaries.each do |file|
      (bin/file).write_env_script neon_storage.opt_libexec/"bin"/file,
                                  POSTGRES_DISTRIB_DIR: neon_postgres.opt_libexec,
                                  NEON_REPO_DIR:        "${NEON_REPO_DIR:-#{var}/neon}"
    end

    bin.install_symlink "neon_local" => "neon-local"
  end

  def post_install
    system bin/"neon_local", "init" unless (var/"neon").exist?
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
    neon_postgres.pg_versions.each do |v|
      vv = v.delete_prefix("v")

      output = shell_output("#{bin}/neon_local tenant create --pg-version #{vv}")
      assert_match(/tenant ([^ ]+) successfully created on the pageserver/, output)
      tenant_id = output.scan(/tenant ([^ ]+) successfully created on the pageserver/).flatten.first

      ep_pg_port = free_port
      system bin/"neon_local", "endpoint", "start", "main-#{v}",
                                           "--pg-version", vv,
                                           "--tenant-id", tenant_id,
                                           "--pg-port", ep_pg_port

      psql = neon_postgres.opt_libexec/v/"bin/psql"
      test_command = %W[
        #{psql}
        --port=#{ep_pg_port}
        --host=127.0.0.1
        --username=cloud_admin
        --dbname=postgres
        --tuples-only
        --command="SELECT VERSION();"
      ].join(" ")

      output = shell_output test_command
      assert_match "PostgreSQL #{vv}", output.strip

      system bin/"neon_local", "endpoint", "stop", "main-#{v}", "--tenant-id", tenant_id
    end
  ensure
    system bin/"neon_local", "stop"
  end
end
