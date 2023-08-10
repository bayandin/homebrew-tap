class NeonLocal < Formula
  desc "CLI for running Neon locally"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon/archive/refs/tags/release-3668.tar.gz"
  sha256 "35020adba0458de9f9d27fd885787ba542a3ad29e165c0cad696d3b3970891be"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "3b3eec59013964e82329d08e99af37ca91682ea79b76dcf981b7d543355a19ab"
    sha256 cellar: :any_skip_relocation, ventura:       "54c20cd57ea08c767b43cd4d55f9ffe2e7d10414679cf62bff7b5d7b3aec56a8"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "bb1cf4d46336822935cf6efdf7fec39a2e20e5002bb66e0c06d484e241adab50"
  end

  depends_on "bayandin/tap/neon-extension"
  depends_on "bayandin/tap/neon-postgres"
  depends_on "bayandin/tap/neon-storage"

  def pg_versions
    %w[v14 v15]
  end

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
    pg_versions.each do |v|
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
