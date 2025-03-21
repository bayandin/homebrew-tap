class Timescaledb < Formula
  desc "Time-series SQL database optimized for fast ingest and complex queries"
  homepage "https://www.timescale.com/"
  url "https://github.com/timescale/timescaledb/archive/refs/tags/2.19.0.tar.gz"
  sha256 "783bfcb6513523827127304d3e51c27e95644f59446bef80d4a96d5de58ae5ee"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "1110d29e2f7b466864a14e066dcb28ecc7409b82696cbb364c38fa0010152796"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "4de09a87f5552b799ad5622b7d60a8b09d7ed83c375daa1c0aac30c2bea4722f"
    sha256 cellar: :any_skip_relocation, ventura:       "321ad9bb5e008457967a69e2ed6de5b4a89a1b2740eb5e2d775f11cc12036d56"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "5761415afc1ed512699da47d1ef1c4ef2ca671520c37cd7fb605a27d67b55cee"
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
      rm_r "build" if Dir.exist?("build")
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
