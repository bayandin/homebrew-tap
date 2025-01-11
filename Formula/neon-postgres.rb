class NeonPostgres < Formula
  desc "Neon's fork of PostgreSQL"
  homepage "https://github.com/neondatabase/postgres"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-compute-7611",
    revision: "3cd601b37091a1a9e38d69c4b46dd9d457fdec38"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  livecheck do
    url :head
    regex(/^release-compute-(\d+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 arm64_sequoia: "77c7a1bd5baba14668955a6aa5a633db26f10056e6f096a6faa01ce353354125"
    sha256 arm64_sonoma:  "a70b57ee68566834b56d7bbdb71336f3ee3cda6295eff7159ceee756ea77c5f1"
    sha256 ventura:       "43062c471e3e489601c009701fe63c98a05e08c595bef8913782aa35663b0de2"
    sha256 x86_64_linux:  "eddba21fe37f60d811ab67ece2d4651b61932e3a6cafeaa56e17802c371e93b9"
  end

  depends_on "docbook" => :build
  depends_on "docbook-xsl" => :build
  depends_on "pkg-config" => :build
  depends_on "icu4c@76"
  depends_on "lz4"
  depends_on "openssl@3"
  depends_on "readline"
  depends_on "zstd"

  uses_from_macos "bison" => :build
  uses_from_macos "flex" => :build
  uses_from_macos "libxml2"
  uses_from_macos "libxslt"
  uses_from_macos "zlib"

  on_linux do
    depends_on "libseccomp"
    depends_on "util-linux"
  end

  def pg_versions(with: nil, without: nil)
    versions = Set.new(%w[v14 v15 v16 v17])
    versions.merge(Array(with))
    versions.subtract(Array(without))
    versions.to_a.sort
  end

  def pg_bin_for(version)
    opt_libexec/version/"bin"
  end

  def pg_lib_for(version)
    opt_libexec/version/"lib"
  end

  def dlsuffix(version)
    # Ref https://github.com/postgres/postgres/commit/b55f62abb2c2e07dfae99e19a2b3d7ca9e58dc1a
    (OS.linux? || "v14 v15".include?(version)) ? "so" : "dylib"
  end

  def install
    ENV["XML_CATALOG_FILES"] = etc/"xml/catalog"
    ENV.append_to_cflags "-DUSE_PREFETCH" if OS.mac?

    deps = %w[openssl@3 readline]
    pg_versions.each do |v|
      cd "vendor/postgres-#{v}" do
        args = %W[
          --prefix=#{libexec}/#{v}
          --datadir=#{HOMEBREW_PREFIX}/share/#{name}/#{v}
          --libdir=#{HOMEBREW_PREFIX}/lib/#{name}/#{v}
          --includedir=#{HOMEBREW_PREFIX}/include/#{name}/#{v}
          --with-includes=#{deps.map { |d| Formula[d].opt_include }.join(" ")}
          --with-libraries=#{deps.map { |d| Formula[d].opt_lib }.join(" ")}
          --enable-debug
          --with-icu
          --with-libxml
          --with-libxslt
          --with-lz4
          --with-ssl=openssl
          --with-uuid=e2fs
        ]
        args << "--with-zstd" if v != "v14"
        args << "PG_SYSROOT=#{MacOS.sdk_path}" if OS.mac? && MacOS.sdk_root_needed?

        system "./configure", *args
        system "make"
        system "make", "install-world", "datadir=#{pkgshare}/#{v}",
                                        "includedir_internal=#{include/name/v}/internal",
                                        "includedir_server=#{include/name/v}/server",
                                        "includedir=#{include/name/v}",
                                        "libdir=#{lib/name/v}",
                                        "pkgincludedir=#{include/name/v}",
                                        "pkglibdir=#{lib/name/v}"
      end

      ln_s lib/name/v, libexec/v/"lib"
      ln_s include/name/v, libexec/v/"include"
      ln_s include/name/v/"server", libexec/v/"include/server"

      next unless OS.linux?
      next unless "v14 v15".include?(v)

      inreplace libexec/v/"lib/pgxs/src/Makefile.global",
                "LD = #{HOMEBREW_PREFIX}/Homebrew/Library/Homebrew/shims/linux/super/ld",
                "LD = #{HOMEBREW_PREFIX}/bin/ld"
    end
  end

  test do
    pg_versions.each do |v|
      system "#{pg_bin_for(v)}/initdb", testpath/"test-#{v}"

      pg_config = pg_bin_for(v)/"pg_config"
      assert_equal "#{HOMEBREW_PREFIX}/share/#{name}/#{v}", shell_output("#{pg_config} --sharedir").chomp
      assert_equal "#{HOMEBREW_PREFIX}/lib/#{name}/#{v}", shell_output("#{pg_config} --libdir").chomp
      assert_equal "#{HOMEBREW_PREFIX}/lib/#{name}/#{v}", shell_output("#{pg_config} --pkglibdir").chomp
      assert_equal "#{HOMEBREW_PREFIX}/include/#{name}/#{v}", shell_output("#{pg_config} --includedir").chomp
    end
  end
end
