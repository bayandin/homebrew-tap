class Timescaledb < Formula
  desc "Time-series SQL database optimized for fast ingest and complex queries"
  homepage "https://www.timescale.com/"
  url "https://github.com/timescale/timescaledb/archive/refs/tags/2.13.0.tar.gz"
  sha256 "584a351c7775f0e067eaa0e7277ea88cab9077cc4c455cbbf09a5d9723dce95d"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any,                 arm64_ventura: "d22cf11e555ce68a97d64e555476fe1f4b12bd2a3a339a8ef0da459369162455"
    sha256 cellar: :any,                 ventura:       "38ca11d5e45d2b836935ec7fdc4124345ea1ae0a98f71179027994b2d85d0b05"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "880823b0a511b106c56554e90a380350c88caf791163b50ea874595d6afff7be"
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
    common_args = std_cmake_args + %w[
      -DAPACHE_ONLY=ON
      -DENABLE_DEBUG_UTILS=OFF
      -DREGRESS_CHECKS=OFF
      -DSEND_TELEMETRY_DEFAULT=OFF
      -DUSE_TELEMETRY=OFF
    ]

    pg_versions.each do |v|
      rm_rf "build"
      system "./bootstrap", *common_args, "-DPG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"
      cd "build" do
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
