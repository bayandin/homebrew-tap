class NeonExtension < Formula
  desc "Extension enabling storage manager API and Pageserver communication"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-compute-8405",
    revision: "e11c4ca77fb559b638621d53700268d68b548f5f"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  livecheck do
    url :head
    regex(/^release-compute-(\d+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_sequoia: "d1b82fc6ad7e999a542e341d99f7dc4dbb733a43998e9b09170d63f5fb047d60"
    sha256 cellar: :any,                 arm64_sonoma:  "7968c3a3999e57836898df772c2c62aa4c03bd1ded2a5594d8d4f289bb186418"
    sha256 cellar: :any,                 ventura:       "2216e6c35ef732f68233cec09ab23104ec17422ebf7c8a41cb8ece33393cb76c"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "9cec6e323d094293b7942b6889e55a4727e45e531c657d85a1a6054fb3da06f2"
  end

  depends_on "bayandin/tap/neon-postgres"
  uses_from_macos "curl"

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
