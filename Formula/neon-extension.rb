class NeonExtension < Formula
  desc "Extension enabling storage manager API and Pageserver communication"
  homepage "https://github.com/neondatabase/neon"
  url "https://github.com/neondatabase/neon/archive/refs/tags/release-3634.tar.gz"
  sha256 "7fecc9e07f391833e25aa6d2817c9ed0799393a0268669d44f4db2e11949f3cb"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_ventura: "d0347ae5e6e7a02082071fcea50eefc218cfd4899a0042c331c5ea3ba9fe9271"
    sha256 cellar: :any,                 ventura:       "a764310f795d47fbf84825a0b14ad0da4a8fb092e50642d72c0aa22b5cef23b0"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "1812151233bd7a39d072a1453a2a3ec4de626ffdb633e442417bea75acfef302"
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
