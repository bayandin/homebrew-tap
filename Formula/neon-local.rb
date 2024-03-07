class NeonLocal < Formula
  desc "CLI for running Neon locally"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-5037",
    revision: "bb7949ba00b1cf359cae6e8fcf92282ea0c48816"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "b279de4d46cdc8d54c02e8560ec7170a26fe4f313732c310d23d496894e72978"
    sha256 cellar: :any_skip_relocation, ventura:      "267ec4619fbdd4516e680f33ff183c63f260f5683d1be8e746b18833f5d89780"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "e8b43b8f0b1fb4248365dfdc6f781e7c79fa3e9d7db431506dc865d6248a6f05"
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

  def pg_versions
    neon_postgres.pg_versions
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

    inreplace neon_repo_dir/"pageserver_1/pageserver.toml" do |s|
      s.gsub! "listen_http_addr ='127.0.0.1:9898'", "listen_http_addr = \"127.0.0.1:#{ps_http_port}\""
      s.gsub! "listen_pg_addr ='127.0.0.1:64000'", "listen_pg_addr = \"127.0.0.1:#{ps_pg_port}\""
      s.gsub! "broker_endpoint ='http://127.0.0.1:50051/'", "broker_endpoint = \"http://127.0.0.1:#{broker_port}/\""
    end

    system bin/"neon_local", "start"
    pg_versions.each do |v|
      vv = v.delete_prefix("v")
      psql = lambda do |sql_query, port|
        %W[
          #{neon_postgres.opt_libexec/v/"bin/psql"}
          --port=#{port}
          --host=127.0.0.1
          --username=cloud_admin
          --dbname=postgres
          --quiet
          --no-align
          --tuples-only
          --command='#{sql_query}'
        ].join(" ")
      end

      tenant_id = SecureRandom.hex

      output = shell_output("#{bin}/neon_local tenant create --pg-version #{vv} --tenant-id #{tenant_id}")
      assert_includes output, "tenant #{tenant_id} successfully created on the pageserver", output

      ep_pg_port = free_port
      system bin/"neon_local", "endpoint", "create", "ep-main-#{v}",
                                                     "--pg-version", vv,
                                                     "--tenant-id", tenant_id,
                                                     "--pg-port", ep_pg_port
      system bin/"neon_local", "endpoint", "start", "ep-main-#{v}"

      output = shell_output psql.call("SELECT VERSION()", ep_pg_port)
      assert_match "PostgreSQL #{vv}", output.strip

      shell_output psql.call("CREATE TABLE test (id SERIAL); INSERT INTO test DEFAULT VALUES", ep_pg_port)
      count_output = shell_output psql.call("SELECT COUNT(*) FROM test", ep_pg_port)
      assert_match "1", count_output

      lsn = shell_output psql.call("SELECT pg_current_wal_flush_lsn()", ep_pg_port)
      system bin/"neon_local", "timeline", "branch",
                                           "--tenant-id", tenant_id,
                                           "--branch-name", "branch",
                                           "--ancestor-start-lsn", lsn,
                                           "--ancestor-branch-name", "main"
      br_ep_pg_port = free_port
      system bin/"neon_local", "endpoint", "create", "ep-branch-#{v}",
                                                     "--pg-version", vv,
                                                     "--branch-name", "branch",
                                                     "--tenant-id", tenant_id,
                                                     "--pg-port", br_ep_pg_port
      system bin/"neon_local", "endpoint", "start", "ep-branch-#{v}"

      count_output = shell_output psql.call("SELECT COUNT(*) FROM test", br_ep_pg_port)
      assert_match "1", count_output

      shell_output psql.call("INSERT INTO test DEFAULT VALUES", br_ep_pg_port)
      count_output = shell_output psql.call("SELECT COUNT(*) FROM test", br_ep_pg_port)
      assert_match "2", count_output

      system bin/"neon_local", "endpoint", "stop", "--destroy", "ep-branch-#{v}"
      system bin/"neon_local", "endpoint", "stop", "--destroy", "ep-main-#{v}"
    end
  ensure
    system bin/"neon_local", "stop"
  end
end
