class NeonExtension < Formula
  desc "Extension enabling storage manager API and Pageserver communication"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-4459",
    revision: "c13a2f0df118708ce4d596528a9cb63ece84a250"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_ventura: "6b8b55543197d6a800e8e97f40e2b0170929c6c1703380cba8f10ae88c5730aa"
    sha256 cellar: :any,                 ventura:       "0f24be1f9f2b1d3d972a7696e771b8566d5a5ba1b3ab61c594a342362bda3204"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "83700033384651e9683a692640b06c77d98c74c1f810c2c5841bf9448e93e81d"
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
