class Plv8 < Formula
  desc "V8 Engine Javascript Procedural Language add-on for PostgreSQL"
  homepage "https://plv8.github.io/"
  url "https://github.com/plv8/plv8.git",
    tag:      "v3.2.0",
    revision: "f23425b5115203d7b339123d5088bf82bfff51cc"
  license "PostgreSQL"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "543723d7db32aaf36f5ce1474ba95028b6b74e9ee3f0f9b9d2d4e9de57e1cf7d"
    sha256 cellar: :any_skip_relocation, ventura:       "6f267acb84cbaa47a4a96e39f816bfb553964cf49506df2da3818690c3d7414f"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "f560a5dadd2a019f9a78cc08a0783fe52c8de7f28e20ddb3a42f6b316ba6fa96"
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
      # Ref https://github.com/postgres/postgres/commit/b55f62abb2c2e07dfae99e19a2b3d7ca9e58dc1a
      dlsuffix = (OS.linux? || "v14 v15".include?(v)) ? "so" : "dylib"

      system "make", "clean", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"
      system "make", "PG_CONFIG=#{neon_postgres.pg_bin_for(v)}/pg_config"
      mkdir_p lib/neon_postgres.name/v
      mv "plv8-#{version}.#{dlsuffix}", lib/neon_postgres.name/v

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
