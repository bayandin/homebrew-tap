class Timescaledb < Formula
  desc "Time-series SQL database optimized for fast ingest and complex queries"
  homepage "https://www.timescale.com/"
  url "https://github.com/timescale/timescaledb/archive/refs/tags/2.12.1.tar.gz"
  sha256 "7e8804122e50807bc214759a59d62ec59b0e96ba681c42bbbc4b4e35fdb48f9c"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_ventura: "0fea8e19d4cc1c9fc06251a04d39767d114d37f4fa76297b04a3ee9cf324cdec"
    sha256 cellar: :any,                 ventura:       "2bab69c807d4e328eed325f63c1c060d571ad343a7cb5a965ef3cbfcac9fb517"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "6a5d8565be94c460d972ed05f15638a25263141805a42fa0579347870204d8e3"
  end

  depends_on "cmake" => :build
  depends_on "bayandin/tap/neon-postgres"

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def pg_versions
    neon_postgres.pg_versions without: "v16"
  end

  def install
    common_args = std_cmake_args + %w[
      -DAPACHE_ONLY=ON
      -DENABLE_DEBUG_UTILS=OFF
      -DREGRESS_CHECKS=OFF
      -DSEND_TELEMETRY_DEFAULT=OFF
      -DUSE_TELEMETRY=OFF
    ]

    pg_versions.each do |v|
      # Ref https://github.com/postgres/postgres/commit/b55f62abb2c2e07dfae99e19a2b3d7ca9e58dc1a
      dlsuffix = (OS.linux? || "v14 v15".include?(v)) ? "so" : "dylib"

      rm_rf "build"
      system "./bootstrap", *common_args, "-DPG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"
      cd "build" do
        system "make"
        system "make", "install", "DESTDIR=#{buildpath}/stage-#{v}"
      end

      stage_dir = Pathname("stage-#{v}#{HOMEBREW_PREFIX}")
      mkdir_p lib/neon_postgres.name/v
      mv Dir[stage_dir/"lib"/neon_postgres.name/v/"*.#{dlsuffix}"], lib/neon_postgres.name/v

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
        shared_preload_libraries = 'timescaledb'
        port = #{port}
      EOS
      system pg_ctl, "start", "-D", testpath/"test-#{v}", "-l", testpath/"log-#{v}"
      begin
        system psql, "-p", port.to_s, "-c", <<~SQL, "postgres"
          CREATE EXTENSION timescaledb;

          -- We start by creating a regular SQL table
          CREATE TABLE conditions (
            time        TIMESTAMPTZ       NOT NULL,
            location    TEXT              NOT NULL,
            temperature DOUBLE PRECISION  NULL,
            humidity    DOUBLE PRECISION  NULL
          );

          -- Then we convert it into a hypertable that is partitioned by time
          SELECT create_hypertable('conditions', 'time');

          INSERT INTO conditions(time, location, temperature, humidity)
            VALUES (NOW(), 'office', 70.0, 50.0);

          SELECT * FROM conditions ORDER BY time DESC LIMIT 100;

          SELECT time_bucket('15 minutes', time) AS fifteen_min,
              location, COUNT(*),
              MAX(temperature) AS max_temp,
              MAX(humidity) AS max_hum
            FROM conditions
            WHERE time > NOW() - interval '3 hours'
            GROUP BY fifteen_min, location
            ORDER BY fifteen_min DESC, max_temp DESC;
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
