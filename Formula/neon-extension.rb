class NeonExtension < Formula
  desc "Extension enabling storage manager API and Pageserver communication"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-4525",
    revision: "aa72a22661ca841868ab11b21137c47e6c07c3e3"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_ventura: "42f31121e61c83c69886cfa60a99fb5c24bb490df071055356bd2ffdab42a3be"
    sha256 cellar: :any,                 ventura:       "813b8129a34a28b363d7d9b540e35d7f418e84dc78070f3c89f35f3bf4c94ef2"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "b2d4e568949d6699ce3ea0771541c8d6576f4f56ecc1ae07cedbb8653c2c6f38"
  end

  depends_on "bayandin/tap/neon-postgres"

  def extensions
    %w[neon_walredo neon neon_rmgr neon_utils]
  end

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def pg_versions
    neon_postgres.pg_versions
  end

  def install
    pg_versions.each do |v|
      cp_r "pgxn", "build-#{v}"
      extensions.each do |ext|
        cd "build-#{v}/#{ext}" do
          system "make", "install", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config",
                                    "DESTDIR=#{buildpath}/stage-#{v}-#{ext}"

          stage_dir = buildpath/"stage-#{v}-#{ext}#{HOMEBREW_PREFIX}"
          share_dir = share/neon_postgres.name/v
          lib_dir = lib/neon_postgres.name/v
          lib_dir.install stage_dir/"lib"/neon_postgres.name/v/"#{ext}.#{neon_postgres.dlsuffix(v)}"
          if File.exist?(stage_dir/"share"/neon_postgres.name/v/"extension/#{ext}.control")
            (share_dir/"extension").install stage_dir/"share"/neon_postgres.name/v/"extension/#{ext}.control"
          end
          (share_dir/"extension").install Dir[stage_dir/"share"/neon_postgres.name/v/"extension/#{ext}--*.sql"]
        end
      end
    end
  end

  test do
    pg_versions.each do |v|
      pg_ctl = neon_postgres.pg_bin_for(v)/"pg_ctl"
      psql = neon_postgres.pg_bin_for(v)/"psql"
      port = free_port

      system pg_ctl, "initdb", "-D", testpath/"test-#{v}"
      (testpath/"test-#{v}/postgresql.conf").write <<~EOS, mode: "a+"

        #{"v14 v15".include?(v) ? "shared_preload_libraries = 'neon'": ""}
        port = #{port}
      EOS
      system pg_ctl, "start", "-D", testpath/"test-#{v}", "-l", testpath/"log-#{v}"
      begin
        (extensions - %w[neon_walredo neon_rmgr]).each do |ext|
          next if "v14 v15".exclude?(v) && ext == "neon"

          system psql, "-p", port.to_s, "-c", "CREATE EXTENSION \"#{ext}\";", "postgres"
        end
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
