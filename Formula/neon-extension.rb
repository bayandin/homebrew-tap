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
    sha256 cellar: :any,                 arm64_ventura: "9aabee476dc3053f3d9c96f997b9396ce5cac097ccc92f18733e534481c97e6d"
    sha256 cellar: :any,                 ventura:       "ff0ea1510436663308a284b3f70a87a04302392f974a4c2f86f4f8fa584eedd6"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "aff87069312441a73736000fdcc119e381b2766f5ed46b3adbc8188f07066d05"
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
