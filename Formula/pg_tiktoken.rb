class PgTiktoken < Formula
  desc "Tiktoken tokenizer for PostgreSQL"
  homepage "https://github.com/kelvich/pg_tiktoken"
  url "https://github.com/kelvich/pg_tiktoken/archive/9118dd4549b7d8c0bbc98e04322499f7bf2fa6f7.tar.gz"
  version "0.0.1"
  sha256 "a5bc447e7920ee149d3c064b8b9f0086c0e83939499753178f7d35788416f628"
  revision 2

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_ventura: "69aaa6728aee67a92f3545c74aedcb1e98094944b5942b89fba621c7eb151178"
    sha256 cellar: :any,                 ventura:       "61e8612ae023570de74631621839abf5e4e3e78a453abacedc2122d52f73bbb0"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "6cd8393f82b6f1f3bb2c29d8e8c09cf42c65359aca63d3cb920c11ee477043a3"
  end

  depends_on "rust" => :build
  depends_on "bayandin/tap/neon-postgres"

  uses_from_macos "llvm" => :build

  resource "pgrx" do
    url "https://github.com/pgcentralfoundation/pgrx/archive/refs/tags/v0.12.6.tar.gz"
    sha256 "ba04f50b3f9f160a1c70861ad2358b3eb6485dbc13608eef09b4094460487a57"
  end

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def pg_versions
    neon_postgres.pg_versions(with: "v17")
  end

  def install
    resource("pgrx").stage do
      system "cargo", "install", *std_cargo_args(root: buildpath/"pgrx", path: "cargo-pgrx")
      ENV.prepend_path "PATH", buildpath/"pgrx/bin"
    end

    # Postgres symbols won't be available until runtime
    ENV["RUSTFLAGS"] = "-Clink-arg=-Wl,-undefined,dynamic_lookup"

    args = []
    pg_versions.each do |v|
      args << "--pg#{v.delete_prefix("v")}" << (neon_postgres.pg_bin_for(v)/"pg_config")
    end
    system "cargo", "pgrx", "init", *args

    pg_versions.each do |v|
      system "cargo", "pgrx", "package", "--profile", "release",
                                         "--pg-config", neon_postgres.pg_bin_for(v)/"pg_config",
                                         "--out-dir", "stage-#{v}"

      stage_dir = Pathname("stage-#{v}#{HOMEBREW_PREFIX}")
      mkdir_p lib/neon_postgres.name/v
      mv stage_dir/"lib/neon-postgres/#{v}/pg_tiktoken.#{neon_postgres.dlsuffix(v)}", lib/neon_postgres.name/v

      from_ext_dir = stage_dir/"share/neon-postgres/#{v}/extension"
      to_ext_dir = share/neon_postgres.name/v/"extension"

      mkdir_p to_ext_dir
      mv from_ext_dir/"pg_tiktoken.control", to_ext_dir
      mv Dir[from_ext_dir/"pg_tiktoken--*.sql"], to_ext_dir
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
          CREATE EXTENSION pg_tiktoken;
          SELECT tiktoken_encode('cl100k_base', 'A long time ago in a galaxy far, far away');
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
