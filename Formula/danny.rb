class Danny < Formula
  desc "Smart bundler analyzer for modern web applications"
  homepage "https://github.com/foxworth-uni/danny"
  url "https://github.com/foxworth-uni/danny/archive/refs/tags/v0.0.7.tar.gz"
  sha256 "976f9c01426f5564fb743633156e88a85a4d68d73cfcb8ec7e4c0dd1f0eb4ae2"
  license "MIT"
  head "https://github.com/foxworth-uni/danny.git", branch: "main"

  bottle do
    root_url "https://github.com/foxworth-uni/danny/releases/download/v0.0.7"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "fa99679f23098292678aa1805c610f405818ca763ca6cb46adb3d5f95d16b710"
    sha256 cellar: :any_skip_relocation, x86_64_sonoma: "b9d9e1d9062347c5f8f80e24bcb8d97f130096ff744dc86278c67e134e9e7617"
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args(path: "crates/danny-cli")
  end

  test do
    assert_match "danny", shell_output("#{bin}/danny --help")
  end
end
