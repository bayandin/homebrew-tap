class Ip4r < Formula
  desc "IPv4/v6 and IPv4/v6 range index type for PostgreSQL"
  homepage "https://github.com/RhodiumToad/ip4r"
  url "https://github.com/RhodiumToad/ip4r/archive/refs/tags/2.4.2.tar.gz"
  sha256 "0f7b1f159974f49a47842a8ab6751aecca1ed1142b6d5e38d81b064b2ead1b4b"
  license "PostgreSQL"
  revision 2

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "7e39f0fde0364dfef3f1e739b242c68ac80ffe143e2b82e945cf7deb3e13b012"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "8ca7da922e3c415b34227be0c6da74c7a49a7b02cee8ff90246aa74cd825580d"
    sha256 cellar: :any_skip_relocation, ventura:       "ff19e1a8a6fd92bf17a23f012f418f9446d1fc037ba66582f63907ad9810d3d0"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "9d8bdd37b49f47b83610ce60bcf57046119a9f5fe38d5985c92fde8222dee873"
  end

  depends_on "bayandin/tap/neon-postgres"

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def pg_versions
    neon_postgres.pg_versions
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
