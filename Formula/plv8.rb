class Plv8 < Formula
  desc "V8 Engine Javascript Procedural Language add-on for PostgreSQL"
  homepage "https://plv8.github.io/"
  url "https://github.com/plv8/plv8.git",
    tag:      "v3.2.3",
    revision: "eef5d3a3b9235f947eb729b3d12a2dd148f6eba9"
  license "PostgreSQL"
  revision 1

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "d555347e003c2cfd6b7981845f434222d1d1a81ea6e01e6b4e4157ace154362e"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "0277867f1a814a11270c138293431dbb82a6bdae079e8a55bdc9ac42f7bfdbcc"
    sha256 cellar: :any_skip_relocation, ventura:       "ab9e1895cd8a70ad12fd64d0385b91a7888d456df6f5bdec0c007e7cbd7a22a7"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "1863f71217a4757cfa8609055026934d9b2ef29bb06148e52364ce6f1e36d1a9"
  end

  depends_on "cmake" => :build
  depends_on "bayandin/tap/neon-postgres"

  def neon_postgres
    Formula["bayandin/tap/neon-postgres"]
  end

  def pg_versions
    neon_postgres.pg_versions(with: "v17")
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
