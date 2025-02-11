class H3Pg < Formula
  desc "PostgreSQL bindings for H3, a hierarchical hexagonal geospatial indexing system"
  homepage "https://github.com/zachasme/h3-pg"
  url "https://github.com/zachasme/h3-pg/archive/refs/tags/v4.2.2.tar.gz"
  sha256 "3c803ece4d7fb8a6880a5e16d4bfcbf060ecc272e5b5b0aa3cd8e11ccb3f8201"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_sequoia: "4390b207e8388b0a987148b0f8a0da72ddf9712797e67ce1ecde76980abff73c"
    sha256 cellar: :any,                 arm64_sonoma:  "641cdc1b1fc258ed1e7b33963d27480025c2a8623f9e1bd35f0ef73fdbe93d0c"
    sha256 cellar: :any,                 ventura:       "130b263744bd6faa17a2585d9597c24b1397da92fa0547cd28948d4fe608327c"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "8efb02bbd876b9a1603741f120c8a24868991277b7cc3040218632ef72ec1a45"
  end

  depends_on "cmake" => :build
  depends_on "bayandin/tap/neon-postgres"

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def pg_versions
    neon_postgres.pg_versions
  end

  def install
    # h3-pg downloads h3 library
    cmake_args = std_cmake_args.reject { |s| s.include? "trap_fetchcontent_provider.cmake" }

    pg_versions.each do |v|
      mkdir buildpath/"build-#{v}"

      cd buildpath/"build-#{v}" do
        system "cmake", "-DPostgreSQL_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config", "..", *cmake_args
        system "make"
        system "make", "install", "DESTDIR=#{buildpath}/stage-#{v}"
      end

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
          CREATE EXTENSION h3;
          SELECT h3_lat_lng_to_cell(POINT('37.3615593,-122.0553238'), 5);
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
