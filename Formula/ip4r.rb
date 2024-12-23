class Ip4r < Formula
  desc "IPv4/v6 and IPv4/v6 range index type for PostgreSQL"
  homepage "https://github.com/RhodiumToad/ip4r"
  url "https://github.com/RhodiumToad/ip4r/archive/refs/tags/2.4.2.tar.gz"
  sha256 "0f7b1f159974f49a47842a8ab6751aecca1ed1142b6d5e38d81b064b2ead1b4b"
  license "PostgreSQL"
  revision 2

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "1fa2970c8694e6402247ccf8e5857126a4b994126db1d65248173f42b311ac6a"
    sha256 cellar: :any_skip_relocation, ventura:       "45532761686d8b3aebbc3828ab662f813286cb7330e2a5ef23bb0f74798bec6e"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "c85e4192af4adf06e0620649839c94177f00b3826a15270fc25f8c7bb1d7abb4"
  end

  depends_on "bayandin/tap/neon-postgres"

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def pg_versions
    neon_postgres.pg_versions(with: "v17")
  end

  def install
    pg_versions.each do |v|
      ENV["PG_CONFIG"] = neon_postgres.pg_bin_for(v)/"pg_config"
      system "make", "clean"
      system "make"
      system "make", "install", "DESTDIR=#{buildpath}/stage-#{v}"

      stage_dir = Pathname("stage-#{v}#{HOMEBREW_PREFIX}")
      mkdir_p lib/neon_postgres.name/v
      mv Dir[stage_dir/"lib"/neon_postgres.name/v/"*.#{neon_postgres.dlsuffix(v)}"], lib/neon_postgres.name/v

      from_ext_dir = stage_dir/"share"/neon_postgres.name/v/"extension"
      to_ext_dir = share/neon_postgres.name/v/"extension"

      mkdir_p to_ext_dir
      mv Dir[from_ext_dir/"*.control"], to_ext_dir
      mv Dir[from_ext_dir/"*--*.sql"], to_ext_dir
    end
  end

  test do
    pg_versions.each do |v|
      pg_ctl = neon_postgres.pg_bin_for(v)/"pg_ctl"
      psql = neon_postgres.pg_bin_for(v)/"psql"
      port = free_port

      system pg_ctl, "initdb", "-D", testpath/"test-#{v}"
      (testpath/"test-#{v}/postgresql.conf").write <<~EOS, mode: "a+"
        port = #{port}
      EOS
      system pg_ctl, "start", "-D", testpath/"test-#{v}", "-l", testpath/"log-#{v}"
      begin
        system psql, "-p", port.to_s, "-c", <<~SQL, "postgres"
          CREATE EXTENSION ip4r;
          SELECT '0.0.0.0'::ip4;
          SELECT '0:0:0:0:0:0:0:0'::ip6;
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
