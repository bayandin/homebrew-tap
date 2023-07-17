class NeonExtension < Formula
  desc "Extension enabling storage manager API and Pageserver communication"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon/archive/refs/tags/release-3509.tar.gz"
  sha256 "465e01f00fa60a506c32cb08446c7d1920383f01599219fc38ecbfb2201a85eb"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 ventura:      "bce41e6bda6d85699f9060d02e7af2cae5ab06d9304cbb1dac80a6ea4a86722e"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "c15c102e9494a81c3ccf112f1080b5beed361db3151bf4598d3a040f0717e960"
  end

  depends_on "bayandin/tap/neon-postgres"

  def pg_versions
    %w[v14 v15]
  end

  def extensions
    %w[neon neon_utils neon_walredo]
  end

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def install
    pg_versions.each do |v|
      extensions.each do |ext|
        cp_r "pgxn/#{ext}", "build-#{ext}-#{v}"
        cd "build-#{ext}-#{v}" do
          system "make", "PG_CONFIG=#{neon_postgres.opt_libexec/v}/bin/pg_config"

          (lib/neon_postgres.name/v).install "#{ext}.so"
          (share/neon_postgres.name/v/"extension").install "#{ext}.control" if File.exist?("#{ext}.control")
          (share/neon_postgres.name/v/"extension").install Dir["#{ext}--*.sql"]
        end
      end
    end
  end

  test do
    pg_versions.each do |v|
      pg_ctl = neon_postgres.opt_libexec/v/"bin/pg_ctl"
      psql = neon_postgres.opt_libexec/v/"bin/psql"
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
