class Danny < Formula
  desc "Smart bundler analyzer for modern web applications"
  homepage "https://github.com/foxworth-uni/danny"
  url "https://github.com/foxworth-uni/danny/archive/refs/tags/v0.0.3.tar.gz"
  sha256 "07005b29590580068afacf10186232fcb9949689e249216a8ecd2ff845b8af0f"
  license "MIT"
  head "https://github.com/foxworth-uni/danny.git", branch: "main"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args(path: "crates/danny-cli")
  end

  test do
    assert_match "danny", shell_output("#{bin}/danny --help")
  end
end

