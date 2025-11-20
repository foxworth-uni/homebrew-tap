#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'digest/sha2'
require 'uri'

# ANSI color helpers
module Colors
  def red(str); "\e[31m#{str}\e[0m"; end
  def green(str); "\e[32m#{str}\e[0m"; end
  def yellow(str); "\e[33m#{str}\e[0m"; end
  def blue(str); "\e[34m#{str}\e[0m"; end
  def magenta(str); "\e[35m#{str}\e[0m"; end
  def cyan(str); "\e[36m#{str}\e[0m"; end
  def gray(str); "\e[90m#{str}\e[0m"; end
  def bold(str); "\e[1m#{str}\e[0m"; end
end

include Colors

# Fetch SHA256 from URL (follows redirects)
def fetch_sha256(url, label)
  print "#{cyan("🍺")} #{label.ljust(30)} "
  STDOUT.flush
  
  uri = URI(url)
  
  # Follow redirects (GitHub uses 302 redirects)
  redirects = 0
  loop do
    response = Net::HTTP.get_response(uri)
    
    case response
    when Net::HTTPSuccess
      sha = Digest::SHA256.hexdigest(response.body)
      puts green("✓ #{sha[0..15]}...")
      return sha
    when Net::HTTPRedirection
      redirects += 1
      if redirects > 5
        puts red("✗ Too many redirects")
        return nil
      end
      uri = URI(response['location'])
    else
      puts red("✗ Failed (#{response.code})")
      puts gray("   #{url}")
      return nil
    end
  end
rescue => e
  puts red("✗ Error: #{e.message}")
  nil
end

# Detect latest version from git tags
def detect_latest_version(repo)
  tags = `git ls-remote --tags https://github.com/#{repo}.git 2>/dev/null`
  versions = tags.scan(/refs\/tags\/v(\d+\.\d+\.\d+)$/).flatten
  versions.max_by { |v| v.split('.').map(&:to_i) }
rescue
  nil
end

# Extract metadata from existing formula
def extract_formula_metadata(formula_path)
  content = File.read(formula_path)
  {
    desc: content[/desc "(.+)"/, 1],
    homepage: content[/homepage "(.+)"/, 1],
    crate_path: content[/path: "(.+)"/, 1] || "crates/#{File.basename(formula_path, '.rb')}-cli"
  }
end

# Confirm action
def confirm(prompt, non_interactive: false)
  if non_interactive
    puts gray("→ #{prompt} [auto-yes]")
    return true
  end
  
  print "#{yellow("?")} #{prompt} (y/N): "
  response = $stdin.gets.chomp
  response.downcase == 'y' || response.downcase == 'yes'
end

# Main script
def main
  # Parse flags
  dry_run = ARGV.delete('--dry-run') || ARGV.delete('-d')
  non_interactive = dry_run || !$stdin.tty?
  
  formula = ARGV[0]
  version = ARGV[1]
  
  unless formula
    puts red("❌ Usage: ruby update-formula.rb <formula> [version] [--dry-run]")
    exit 1
  end
  
  formula_file = "Formula/#{formula}.rb"
  
  unless File.exist?(formula_file)
    puts red("❌ Formula not found: #{formula_file}")
    exit 1
  end
  
  repo = "foxworth-uni/#{formula}"
  
  # Get or detect version
  if version.nil? || version.empty?
    puts blue("📦 Detecting latest version for #{formula}...")
    detected = detect_latest_version(repo)
    version = detected || "0.0.1"
    
    if non_interactive
      puts cyan("🎯 Using detected version: #{version}")
    else
      print "#{cyan("🎯")} Version [#{version}]: "
      input = $stdin.gets.chomp
      version = input unless input.empty?
    end
  end
  
  puts
  puts bold(magenta("Updating #{formula} to v#{version}"))
  if dry_run
    puts yellow("🔍 DRY RUN MODE - No changes will be made")
  end
  puts
  
  if non_interactive
    puts gray("→ Auto-proceeding (non-interactive mode)")
  else
    return unless confirm("Fetch SHA256 hashes for v#{version}?")
  end
  
  puts
  
  # Fetch source SHA
  source_url = "https://github.com/#{repo}/archive/refs/tags/v#{version}.tar.gz"
  source_sha = fetch_sha256(source_url, "Source tarball")
  
  unless source_sha
    puts red("❌ Failed to fetch source. Does v#{version} exist?")
    exit 1
  end
  
  # Fetch ARM64 bottle
  arm64_url = "https://github.com/#{repo}/releases/download/v#{version}/#{formula}-#{version}.arm64_sonoma.bottle.tar.gz"
  arm64_sha = fetch_sha256(arm64_url, "ARM64 bottle (Apple Silicon)")
  
  unless arm64_sha
    puts red("❌ Bottles not ready. Check GitHub Actions:")
    puts gray("   https://github.com/#{repo}/actions")
    exit 1
  end
  
  # Fetch x86_64 bottle
  x86_url = "https://github.com/#{repo}/releases/download/v#{version}/#{formula}-#{version}.x86_64_sonoma.bottle.tar.gz"
  x86_sha = fetch_sha256(x86_url, "x86_64 bottle (Intel)")
  
  unless x86_sha
    puts red("❌ Failed to fetch x86_64 bottle")
    exit 1
  end
  
  # Extract existing metadata
  metadata = extract_formula_metadata(formula_file)
  
  # Show summary
  puts
  puts "┌" + "─" * 68 + "┐"
  puts "│ #{bold(formula)} v#{version}".ljust(77) + "│"
  puts "├" + "─" * 68 + "┤"
  puts "│ Source:  #{source_sha[0..15]}...#{source_sha[48..63]}".ljust(77) + "│"
  puts "│ ARM64:   #{arm64_sha[0..15]}...#{arm64_sha[48..63]}".ljust(77) + "│"
  puts "│ x86_64:  #{x86_sha[0..15]}...#{x86_sha[48..63]}".ljust(77) + "│"
  puts "└" + "─" * 68 + "┘"
  puts
  
  return unless confirm("Update #{formula_file}?", non_interactive: non_interactive)
  
  # Generate formula class name (snake_case to CamelCase)
  class_name = formula.split('-').map(&:capitalize).join
  
  # Write formula
  if dry_run
    puts yellow("🔍 DRY RUN: Would write to #{formula_file}")
  else
    File.write(formula_file, <<~RUBY)
    class #{class_name} < Formula
      desc "#{metadata[:desc]}"
      homepage "#{metadata[:homepage]}"
      url "https://github.com/#{repo}/archive/refs/tags/v#{version}.tar.gz"
      sha256 "#{source_sha}"
      license "MIT"
      head "https://github.com/#{repo}.git", branch: "main"

      bottle do
        root_url "https://github.com/#{repo}/releases/download/v#{version}"
        sha256 cellar: :any_skip_relocation, arm64_sonoma: "#{arm64_sha}"
        sha256 cellar: :any_skip_relocation, x86_64_sonoma: "#{x86_sha}"
      end

      depends_on "rust" => :build

      def install
        system "cargo", "install", *std_cargo_args(path: "#{metadata[:crate_path]}")
      end

      test do
        assert_match "#{formula}", shell_output("\#{bin}/#{formula} --help")
      end
    end
  RUBY
  end
  
  puts green("✅ Formula #{dry_run ? 'would be' : ''} updated!")
  puts
  
  # Show diff (or preview in dry run)
  if dry_run
    puts yellow("🔍 DRY RUN: Preview of formula:")
    puts gray("─" * 70)
    puts gray("class #{class_name} < Formula")
    puts gray("  desc \"#{metadata[:desc]}\"")
    puts gray("  url \"...v#{version}.tar.gz\"")
    puts gray("  sha256 \"#{source_sha[0..15]}...\"")
    puts gray("  # ... (full formula would be written)")
    puts gray("─" * 70)
  else
    system("git", "diff", formula_file)
  end
  puts
  
  return unless confirm("Commit changes?", non_interactive: non_interactive)
  
  if dry_run
    puts yellow("🔍 DRY RUN: Would commit with message: chore: update #{formula} to v#{version}")
  else
    system("git", "add", formula_file)
    system("git", "commit", "-m", "chore: update #{formula} to v#{version}")
    puts green("✅ Committed")
  end
  puts
  
  return unless confirm("Push to origin?", non_interactive: non_interactive)
  
  if dry_run
    puts yellow("🔍 DRY RUN: Would push to origin/main")
  else
    system("git", "push", "origin", "main")
  end
  puts
  puts green("🚀 #{dry_run ? '[DRY RUN] Would be r' : 'R'}eleased!")
  puts gray("   brew install foxworth-uni/tap/#{formula}")
end

main if __FILE__ == $PROGRAM_NAME

