class NeonExtension < Formula
  desc "Extension enabling storage manager API and Pageserver communication"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-4030",
    revision: "face60d50baba9cd8e14aed34e7cfa3c21a6b4e7"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_ventura: "e7be479ebd547cd5ca5a23805ebea4e32411efd66e63a7c74fb0b075d2de4bd3"
    sha256 cellar: :any,                 ventura:       "9268e0655980ab6a6b231d38a07c489516a93568a404c1e1823702d13c4510fc"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "bf845a0782972e565c1f87255a01f9af166ad6bc61d14b1dbfb774ace25560b0"
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
      # Ref https://github.com/postgres/postgres/commit/b55f62abb2c2e07dfae99e19a2b3d7ca9e58dc1a
      dlsuffix = (OS.linux? || "v14 v15".include?(v)) ? "so" : "dylib"

      cp_r "pgxn", "build-#{v}"
      extensions.each do |ext|
        cd "build-#{v}/#{ext}" do
          system "make", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"

          (lib/neon_postgres.name/v).install "#{ext}.#{dlsuffix}"
          (share/neon_postgres.name/v/"extension").install "#{ext}.control" if File.exist?("#{ext}.control")
          (share/neon_postgres.name/v/"extension").install Dir["#{ext}--*.sql"]
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
