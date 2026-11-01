# Built from source on the user's Mac: nothing is downloaded with a quarantine flag, so
# Gatekeeper asks nothing, and no Developer ID is needed. The CLI is diskmap's own code under
# libexec, run by Homebrew's Python; the window, diskmap.app, is compiled here by swiftc from
# the Command Line Tools and runs that same CLI.
class Diskmap < Formula
  desc "Partition map and layout planner for external drives on macOS"
  homepage "https://github.com/zapotylok/diskmap"
  url "https://github.com/zapotylok/diskmap/archive/refs/tags/v2026.1101.2.tar.gz"
  sha256 "fec617d6bd2d354918c964cf2af346d30f98dee8d5fadea08b53c6909231379a"
  license "MIT"

  depends_on arch: :arm64
  depends_on macos: :sequoia # K19: tested on macOS 26 only; elsewhere every plan says so first
  depends_on "python@3.14"

  def python3
    formula_opt_bin("python@3.14")/"python3.14"
  end

  def install
    # The window first: build.sh reads the version from core/, which libexec.install moves away.
    ENV["OUT"] = prefix.to_s
    ENV["PYTHON"] = python3.to_s
    system "app/build.sh", "--command", (opt_bin/"diskmap").to_s

    libexec.install "core", "cli", "ui"
    # Run isolated (-I): no current folder on sys.path, no PYTHON* variables — a cli/ or core/
    # in the folder diskmap is started in must not run instead of diskmap, least of all under
    # sudo. The launcher puts its own folder first instead.
    (libexec/"diskmap.py").write <<~PYTHON
      import os, sys
      sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
      from cli.main import main
      sys.exit(main(sys.argv[1:]))
    PYTHON
    (bin/"diskmap").write <<~SH
      #!/bin/sh
      exec "#{python3}" -I "#{opt_libexec}/diskmap.py" "$@"
    SH
    # Bytecode now: Terminal runs `sudo python -m cli apply` in libexec (ui/terminal.py), and
    # root must not write it there.
    system python3, "-m", "compileall", "-q", libexec
  end

  def caveats
    <<~EOS
      The window is #{opt_prefix}/diskmap.app. To have it in Launchpad and Spotlight:
        diskmap install-app
      It copies the window into /Applications (or ~/Applications). The copy runs
      #{opt_bin}/diskmap, so after `brew upgrade` it runs the new version; run
      install-app again for a newer window.

      diskmap only reads until you apply a plan: writing is `sudo diskmap apply …` in Terminal,
      which the window opens for you. Back up the files on a disk before writing to it.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/diskmap --version")
    assert_path_exists prefix/"diskmap.app/Contents/MacOS/diskmap"
    system bin/"diskmap", "install-app", "--to", testpath/"Applications"
    assert_path_exists testpath/"Applications/diskmap.app/Contents/MacOS/diskmap"
    system "codesign", "--verify", "--strict", prefix/"diskmap.app"
  end
end
