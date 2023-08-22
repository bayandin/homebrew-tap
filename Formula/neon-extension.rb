class NeonExtension < Formula
  desc "Extension enabling storage manager API and Pageserver communication"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon/archive/refs/tags/release-3756.tar.gz"
  sha256 "1a6d1469df36772a6ba74f850877c72864ab28a43a5e2aecae5374304c6faffa"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_ventura: "df0cd09b985838d443c3410eae524a54dabe2ceb2df20662648d46c31754744a"
    sha256 cellar: :any,                 ventura:       "6be8606a9b780abcdd3e6e8ddf191d479d511b5d6588b789c4cb62cdfef78036"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "7c68673871e6257e557776cb76fbfdb343b1a56be10e44d7dd61a216661eecdc"
  end

  depends_on "bayandin/tap/neon-postgres"

  def extensions
    %w[neon neon_utils neon_walredo]
  end

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def install
    neon_postgres.pg_versions.each do |v|
      extensions.each do |ext|
        cp_r "pgxn/#{ext}", "build-#{ext}-#{v}"
        cd "build-#{ext}-#{v}" do
          system "make", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"

          (lib/neon_postgres.name/v).install "#{ext}.so"
          (share/neon_postgres.name/v/"extension").install "#{ext}.control" if File.exist?("#{ext}.control")
          (share/neon_postgres.name/v/"extension").install Dir["#{ext}--*.sql"]
        end
      end
    end
  end

  test do
    neon_postgres.pg_versions.each do |v|
      pg_ctl = neon_postgres.pg_bin_for(v)/"pg_ctl"
      psql = neon_postgres.pg_bin_for(v)/"psql"
      port = free_port

      system pg_ctl, "initdb", "-D", testpath/"test-#{v}"
      (testpath/"test-#{v}/postgresql.conf").write <<~EOS, mode: "a+"

        shared_preload_libraries = 'neon'
        port = #{port}
      EOS
      system pg_ctl, "start", "-D", testpath/"test-#{v}", "-l", testpath/"log-#{v}"
      begin
        (extensions - %w[neon_walredo]).each do |ext|
          system psql, "-p", port.to_s, "-c", "CREATE EXTENSION \"#{ext}\";", "postgres"
        end
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
