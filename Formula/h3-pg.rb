class H3Pg < Formula
  desc "PostgreSQL bindings for H3, a hierarchical hexagonal geospatial indexing system"
  homepage "https://github.com/zachasme/h3-pg"
  url "https://github.com/zachasme/h3-pg/archive/refs/tags/v4.1.4.tar.gz"
  sha256 "a7b5de78ec3874b284e7ef4ee7639c0c40e3ab49fa6eba0c53caef90a913994a"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    rebuild 1
    sha256 cellar: :any,                 arm64_sequoia: "9c14ac193007bf69b6a5dabe87eac6a406e8f5e589239fc29af5c439cd721901"
    sha256 cellar: :any,                 arm64_sonoma:  "5f49e3a36e30397c269cf1d22c1ee0dcf62b17caca2e6c639d7d5b626a078319"
    sha256 cellar: :any,                 ventura:       "404f8dd38eab72294e19f402c909be0fce9710b785a0cea198fadf3fda6466d8"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "8659856ed57b32f5a32de6f3a4e331c894a405643d40539eaafd326ce3833484"
  end

  depends_on "cmake" => :build
  depends_on "bayandin/tap/neon-postgres"

  # Fix build on MacOS
  # Remove in the next release
  patch do
    url "https://github.com/zachasme/h3-pg/commit/c6daef9b2dcf431a020bc780f9ba942dd1d825d5.patch?full_index=1"
    sha256 "668ff699da4f8bd0662a47242e516ea73a9a55b2c97e82f77d8d8939ac2766e7"
  end

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def pg_versions
    neon_postgres.pg_versions(with: "v17")
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
