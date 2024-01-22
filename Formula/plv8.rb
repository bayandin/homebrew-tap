class Plv8 < Formula
  desc "V8 Engine Javascript Procedural Language add-on for PostgreSQL"
  homepage "https://plv8.github.io/"
  url "https://github.com/plv8/plv8.git",
    tag:      "v3.2.2",
    revision: "fa9f0146a2eeb11083566b647d153432cd9b976e"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "3d7806be0e09f53aba88933ac3c7fd97763c691c4b678d8ea67634158c9d87a8"
    sha256 cellar: :any_skip_relocation, ventura:       "cee79f36989ff42d81e6cf39bb409626e8607bd025bcd33011c35dd2c4a20fea"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "73ad8b96c3c85d0bd9c17736a296d8959450fd86df1aba3fb28307f04aa7fc15"
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
    inreplace "Makefile", "-DCMAKE_BUILD_TYPE=Release",
                          "-DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=#{ENV.cc} -DCMAKE_CXX_COMPILER=#{ENV.cxx}"

    pg_versions.each do |v|
      system "make", "clean", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"
      system "make", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"
      mkdir_p lib/neon_postgres.name/v
      mv "plv8-#{version}.#{neon_postgres.dlsuffix(v)}", lib/neon_postgres.name/v

      mkdir_p share/neon_postgres.name/v/"extension"
      cp "plv8.control", share/neon_postgres.name/v/"extension"
      cp Dir["plv8--*.sql"], share/neon_postgres.name/v/"extension"
      cp Dir["upgrade/plv8--*.sql"], share/neon_postgres.name/v/"extension"
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
          CREATE EXTENSION plv8;
          CREATE FUNCTION plv8_test(keys TEXT[], vals TEXT[]) RETURNS JSON AS $$
            var o = {};
            for(var i=0; i<keys.length; i++){
                o[keys[i]] = vals[i];
            }
            return o;
          $$ LANGUAGE plv8 IMMUTABLE STRICT;
          SELECT plv8_test(ARRAY['name', 'age'], ARRAY['Tom', '29']);
        SQL
      ensure
        system pg_ctl, "stop", "-D", testpath/"test-#{v}"
      end
    end
  end
end
