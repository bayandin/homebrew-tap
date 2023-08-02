class NeonExtension < Formula
  desc "Extension enabling storage manager API and Pageserver communication"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon/archive/refs/tags/release-3632.tar.gz"
  sha256 "4d77ccfa6bc09979ad1f9cccc834e645809774a6ea5720a44acc52fed1aaa49d"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_ventura: "9941b5f466c02fb3082076a82b3a510b75ab6f76373034775a2e1f9e992ab6d5"
    sha256 cellar: :any,                 ventura:       "0ac389e326b4a5eed8bbab74cc203d9f048f5c0271b79f76f9c9b6455a9c3e8b"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "7dfae80dc4426412891043594ffa27429b4966404ef5ac544959958147b34520"
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
