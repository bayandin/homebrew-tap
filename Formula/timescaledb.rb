class Timescaledb < Formula
  desc "Time-series SQL database optimized for fast ingest and complex queries"
  homepage "https://www.timescale.com/"
  url "https://github.com/timescale/timescaledb/archive/refs/tags/2.17.2.tar.gz"
  sha256 "b2fcc29e9975b88c5323aefb062346326694c391d52af46186f5a5ad09136d47"
  license "Apache-2.0"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "2a409b4f4cb8c75df72ee9e8ea68ce560f1e8e7c11890d5fe75fe1ef63e14fee"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "79094f02323956c5efd70bcc5203c8b7681905e1f3755808671f1b96e1896c10"
    sha256 cellar: :any_skip_relocation, ventura:       "19fa43f4f1dc153d4ea0c229ccc3d896532a5e0a982727d8e8e432f8207d563c"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "d36cb032b9f8635f4711608f104b352dd369e374653a4000f8152d29c4d5964d"
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
