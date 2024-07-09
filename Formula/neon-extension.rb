class NeonExtension < Formula
  desc "Extension enabling storage manager API and Pageserver communication"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-5889",
    revision: "a5491463e1cc6faf439d04a697630b7f00741d48"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  livecheck do
    url :head
    regex(/^release-(\d+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_sonoma: "0afad4a4d3d99e432bb0ac871f6235f7bfafdc1c6a99c07c6e477f799b3963a5"
    sha256 cellar: :any,                 ventura:      "b6a925aa4c8f8dbe660570a29687868219be7897c72767530df8f7ae505ed5df"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "04078936aaf0c725bc10eaf5b9d9e8269087a2ba22671b68fac91d393aca81bf"
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
