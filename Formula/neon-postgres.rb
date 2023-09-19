class NeonPostgres < Formula
  desc "Neon's fork of PostgreSQL"
  homepage "https://github.com/neondatabase/postgres"
  url "https://github.com/neondatabase/neon.git",
    tag:      "release-3940",
    revision: "52a88af0aaa5b38e9cd881b45599a25feb19c199"
  license "Apache-2.0"
  head "https://github.com/neondatabase/neon.git", branch: "main"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 arm64_ventura: "8736a9fc38d8ecd59c5b18844f197d83f596e253a4144ecff0971ffb6623853b"
    sha256 ventura:       "bff414bcc9bde93391ee42c9ff1e81f45331107c9feacf6e5968b27195e2dd4d"
    sha256 x86_64_linux:  "db3a501e122c80f9d8361c697c43927024cdc30b0b614136580e8e7c284d39a1"
  end

  depends_on "docbook" => :build
  depends_on "docbook-xsl" => :build
  depends_on "pkg-config" => :build
  depends_on "icu4c"
  depends_on "lz4"
  depends_on "openssl@3"
  depends_on "readline"
  depends_on "zstd"

  uses_from_macos "curl"
  uses_from_macos "libxml2"
  uses_from_macos "libxslt"

  on_linux do
    depends_on "libseccomp"
  end

  def pg_versions(with: nil)
    versions = Set.new(%w[v14 v15])
    versions.merge(Array(with))
    versions.to_a.sort
  end

  def pg_bin_for(version)
    opt_libexec/version/"bin"
  end

  def install
    ENV["XML_CATALOG_FILES"] = etc/"xml/catalog"

    ENV.prepend "LDFLAGS", "-L#{Formula["openssl@3"].opt_lib} -L#{Formula["readline"].opt_lib}"
    ENV.prepend "CPPFLAGS", "-I#{Formula["openssl@3"].opt_include} -I#{Formula["readline"].opt_include}"

    if OS.linux?
      ENV.prepend "LDFLAGS", "-L#{Formula["curl"].opt_lib}"
      ENV.prepend "CPPFLAGS", "-I#{Formula["curl"].opt_include}"
    end

    pg_versions(with: "v16").each do |v|
      cd "vendor/postgres-#{v}" do
        args = %W[
          --prefix=#{libexec}/#{v}
          --datadir=#{HOMEBREW_PREFIX}/share/#{name}/#{v}
          --libdir=#{HOMEBREW_PREFIX}/lib/#{name}/#{v}
          --includedir=#{HOMEBREW_PREFIX}/include/#{name}/#{v}
          --enable-debug
          --with-icu
          --with-libxml
          --with-libxslt
          --with-lz4
          --with-ssl=openssl
          --with-uuid=e2fs
        ]
        args << "--with-zstd" if v != "v14"
        args << "PG_SYSROOT=#{MacOS.sdk_path}" if MacOS.sdk_root_needed?

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
    pg_versions(with: "v16").each do |v|
      system "#{pg_bin_for(v)}/initdb", testpath/"test-#{v}"

      pg_config = pg_bin_for(v)/"pg_config"
      assert_equal "#{HOMEBREW_PREFIX}/share/#{name}/#{v}", shell_output("#{pg_config} --sharedir").chomp
      assert_equal "#{HOMEBREW_PREFIX}/lib/#{name}/#{v}", shell_output("#{pg_config} --libdir").chomp
      assert_equal "#{HOMEBREW_PREFIX}/lib/#{name}/#{v}", shell_output("#{pg_config} --pkglibdir").chomp
      assert_equal "#{HOMEBREW_PREFIX}/include/#{name}/#{v}", shell_output("#{pg_config} --includedir").chomp
    end
  end
end
