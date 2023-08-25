class Toxiproxy < Formula
  desc "TCP proxy to simulate network & system conditions for chaos & resiliency testing"
  homepage "https://github.com/shopify/toxiproxy"
  url "https://github.com/Shopify/toxiproxy/archive/refs/tags/v2.6.0.tar.gz"
  sha256 "17bf7580644a5cf8d6fc2b5a71e8dc7931528838724a6e4dc2bb326731fab4c7"
  license "MIT"

  depends_on "go" => :build

  def install
    ldflags = "-s -w -X github.com/Shopify/toxiproxy/v2.Version=#{version}"
    system "go", "build", *std_go_args(ldflags: ldflags), "-o", bin/"toxiproxy-server", "./cmd/server"
    system "go", "build", *std_go_args(ldflags: ldflags), "-o", bin/"toxiproxy-cli", "./cmd/cli"
  end

  service do
    run opt_bin/"toxiproxy-server"
    keep_alive true
    log_path var/"log/toxiproxy.log"
    error_log_path var/"log/toxiproxy.log"
  end

  test do
    require "webrick"

    assert_match version.to_s, shell_output(bin/"toxiproxy-server --version")
    assert_match version.to_s, shell_output(bin/"toxiproxy-cli --version")

    proxy_port = free_port
    fork { system bin/"toxiproxy-server", "--port", proxy_port.to_s }

    upstream_port = free_port
    server = WEBrick::HTTPServer.new Port: upstream_port
    server.mount_proc("/") { |_req, res| res.body = "Hello Homebrew" }

    Thread.new { server.start }
    sleep(3)

    begin
      listen_port = free_port
      system bin/"toxiproxy-cli", "--host", "127.0.0.1:#{proxy_port}", "create",
                                  "--listen", "127.0.0.1:#{listen_port}",
                                  "--upstream", "127.0.0.1:#{upstream_port}",
                                  "hello-homebrew"

      assert_equal "Hello Homebrew", shell_output("curl -s http://127.0.0.1:#{listen_port}/")
    ensure
      server.shutdown
    end
  end
end
