class TpcH < Formula
  desc "Decision Support Benchmark"
  homepage "https://www.tpc.org/tpch/"
  url "https://github.com/bayandin/tpc-h/archive/refs/tags/v3.0.1.tar.gz"
  sha256 "fd55f79713de8cf4074a998f4ecbc1012cee529dc192ca529489830d3c951859"

  bottle do
    root_url "https://ghcr.io/v2/bayandin/tap"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "d9b860f772eb3f37131429151f86148baa2b70caee54ebe56fdf063b3b5a908e"
    sha256 cellar: :any_skip_relocation, ventura:       "fee79ff3d7f3f2d45f674916d273c0671f051d1fbf201e5c264786b881c2201c"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "1333691274bcfa60c96b6c2040b2f70afbe0d72f5a45259591e1b96571f464f1"
  end

  depends_on "postgresql@15" => :test

  # Support macOS
  patch do
    url "https://gist.githubusercontent.com/bayandin/40961b83d48cac26471ce6f39405dcd6/raw/bb17f78ddd0b8d5a3dd0ea0c142ab58eb7dcaed5/0001-Support-macOS.patch"
    sha256 "156f438d343da51ef1ba08ad065909966ff324d9e30fb7abe7202520cbb53133"
  end

  # Support Postgres
  patch do
    url "https://gist.githubusercontent.com/bayandin/40961b83d48cac26471ce6f39405dcd6/raw/bb17f78ddd0b8d5a3dd0ea0c142ab58eb7dcaed5/0002-Support-Postgres.patch"
    sha256 "341075ee411c14e0bc6d497b3381d5c3d215d231a4f26642c282a70cec9cf4e2"
  end

  def schema
    <<~SQL
      CREATE TABLE nation ( n_nationkey INTEGER NOT NULL, n_name CHAR(25) NOT NULL, n_regionkey INTEGER NOT NULL,
                            n_comment VARCHAR(152));
      CREATE TABLE region ( r_regionkey INTEGER NOT NULL, r_name CHAR(25) NOT NULL, r_comment VARCHAR(152));
      CREATE TABLE part ( p_partkey INTEGER NOT NULL, p_name VARCHAR(55) NOT NULL, p_mfgr CHAR(25) NOT NULL,
                          p_brand CHAR(10) NOT NULL, p_type VARCHAR(25) NOT NULL, p_size INTEGER NOT NULL,
                          p_container CHAR(10) NOT NULL, p_retailprice DECIMAL(15,2) NOT NULL, p_comment VARCHAR(23) NOT NULL);
      CREATE TABLE supplier ( s_suppkey INTEGER NOT NULL, s_name CHAR(25) NOT NULL, s_address VARCHAR(40) NOT NULL,
                              s_nationkey INTEGER NOT NULL, s_phone CHAR(15) NOT NULL, s_acctbal DECIMAL(15,2) NOT NULL,
                              s_comment VARCHAR(101) NOT NULL);
      CREATE TABLE partsupp ( ps_partkey INTEGER NOT NULL, ps_suppkey INTEGER NOT NULL, ps_availqty INTEGER NOT NULL,
                              ps_supplycost DECIMAL(15,2) NOT NULL, ps_comment VARCHAR(199) NOT NULL );
      CREATE TABLE customer ( c_custkey INTEGER NOT NULL, c_name VARCHAR(25) NOT NULL, c_address VARCHAR(40) NOT NULL,
                              c_nationkey INTEGER NOT NULL, c_phone CHAR(15) NOT NULL, c_acctbal DECIMAL(15,2) NOT NULL,
                              c_mktsegment CHAR(10) NOT NULL, c_comment VARCHAR(117) NOT NULL);
      CREATE TABLE orders ( o_orderkey INTEGER NOT NULL, o_custkey INTEGER NOT NULL, o_orderstatus CHAR(1) NOT NULL,
                            o_totalprice DECIMAL(15,2) NOT NULL, o_orderdate DATE NOT NULL, o_orderpriority CHAR(15) NOT NULL,
                            o_clerk CHAR(15) NOT NULL, o_shippriority INTEGER NOT NULL, o_comment VARCHAR(79) NOT NULL);
      CREATE TABLE lineitem ( l_orderkey INTEGER NOT NULL, l_partkey INTEGER NOT NULL, l_suppkey INTEGER NOT NULL,
                              l_linenumber INTEGER NOT NULL, l_quantity DECIMAL(15,2) NOT NULL,
                              l_extendedprice DECIMAL(15,2) NOT NULL, l_discount DECIMAL(15,2) NOT NULL,
                              l_tax DECIMAL(15,2) NOT NULL, l_returnflag CHAR(1) NOT NULL, l_linestatus CHAR(1) NOT NULL,
                              l_shipdate DATE NOT NULL, l_commitdate DATE NOT NULL, l_receiptdate DATE NOT NULL,
                              l_shipinstruct CHAR(25) NOT NULL, l_shipmode CHAR(10) NOT NULL, l_comment VARCHAR(44) NOT NULL);
    SQL
  end

  def indexes
    <<~SQL
      ALTER TABLE part ADD PRIMARY KEY (p_partkey);
      ALTER TABLE supplier ADD PRIMARY KEY (s_suppkey);
      ALTER TABLE partsupp ADD PRIMARY KEY (ps_partkey, ps_suppkey);
      ALTER TABLE customer ADD PRIMARY KEY (c_custkey);
      ALTER TABLE orders ADD PRIMARY KEY (o_orderkey);
      ALTER TABLE lineitem ADD PRIMARY KEY (l_orderkey, l_linenumber);
      ALTER TABLE nation ADD PRIMARY KEY (n_nationkey);
      ALTER TABLE region ADD PRIMARY KEY (r_regionkey);
      CREATE INDEX ON supplier USING btree (s_nationkey);
      ALTER TABLE supplier ADD FOREIGN KEY (s_nationkey) REFERENCES nation (n_nationkey);
      CREATE INDEX ON partsupp USING btree (ps_suppkey);
      ALTER TABLE partsupp ADD FOREIGN KEY (ps_partkey) REFERENCES part (p_partkey);
      ALTER TABLE partsupp ADD FOREIGN KEY (ps_suppkey) REFERENCES supplier (s_suppkey);
      CREATE INDEX ON customer USING btree (c_nationkey);
      ALTER TABLE customer ADD FOREIGN KEY (c_nationkey) REFERENCES nation (n_nationkey);
      CREATE INDEX ON orders USING btree (o_custkey);
      ALTER TABLE orders ADD FOREIGN KEY (o_custkey) REFERENCES customer (c_custkey);
      CREATE INDEX ON lineitem USING btree (l_partkey, l_suppkey);
      CREATE INDEX ON lineitem USING btree (l_suppkey);
      ALTER TABLE lineitem ADD FOREIGN KEY (l_orderkey) REFERENCES orders (o_orderkey);
      ALTER TABLE lineitem ADD FOREIGN KEY (l_partkey) REFERENCES part (p_partkey);
      ALTER TABLE lineitem ADD FOREIGN KEY (l_suppkey) REFERENCES supplier (s_suppkey);
      ALTER TABLE lineitem ADD FOREIGN KEY (l_partkey, l_suppkey) REFERENCES partsupp (ps_partkey, ps_suppkey);
      CREATE INDEX ON nation USING btree (n_regionkey);
      ALTER TABLE nation ADD FOREIGN KEY (n_regionkey) REFERENCES region (r_regionkey);
      ALTER TABLE lineitem ADD CHECK (l_shipdate <= l_receiptdate);
    SQL
  end

  def install
    database = "POSTGRESQL"
    machine = OS.mac? ? "MACOS" : "LINUX"
    workload = "TPCH"

    cd "dbgen" do
      mv "makefile.suite", "makefile"

      inreplace "makefile" do |s|
        s.gsub! "DATABASE=", "DATABASE = #{database}"
        s.gsub! "MACHINE =", "MACHINE = #{machine}"
        s.gsub! "WORKLOAD =", "WORKLOAD = #{workload}"

        s.gsub! "CC      =", "CC = #{ENV.cc}"
      end

      system "make"

      (libexec/"bin").install "dbgen"
      (libexec/"bin").install "qgen"

      libexec.install "dists.dss"
      libexec.install "queries"
    end

    (bin/"dbgen").write_env_script libexec/"bin/dbgen", DSS_CONFIG: libexec
    (bin/"qgen").write_env_script libexec/"bin/qgen", DSS_CONFIG: libexec, DSS_QUERY: libexec/"queries"

    prefix.install "EULA.txt"
    doc.install "specification.pdf"
  end

  test do
    postgresql = Formula["postgresql@15"]

    pg_ctl = postgresql.opt_bin/"pg_ctl"
    psql = postgresql.opt_bin/"psql"
    port = free_port

    system bin/"dbgen", "-s", "0.05"

    ENV["LC_ALL"] = "C"
    system pg_ctl, "initdb", "-D", testpath/"test"
    (testpath/"test/postgresql.conf").write <<~EOS, mode: "a+"
      port = #{port}
    EOS
    system pg_ctl, "start", "-D", testpath/"test", "-l", testpath/"log"
    begin
      system psql, "-p", port.to_s, "-c", schema, "postgres"
      %w[nation region customer lineitem orders part partsupp supplier].each do |table|
        system psql, "-p", port.to_s, "-c", "\\copy #{table} from '#{table}.tbl' DELIMITER '|';", "postgres"
      end
      system psql, "-p", port.to_s, "-c", indexes, "postgres"
    ensure
      system pg_ctl, "stop", "-D", testpath/"test"
    end
  end
end
