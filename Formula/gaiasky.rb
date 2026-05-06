# Formula/gaiasky.rb
class Gaiasky < Formula
  desc "Real-time 3D Universe platform with support for more than a billion objects"
  homepage "https://gaiasky.space"
  license "MPL-2.0"

  url "https://codeberg.org/gaiasky/gaiasky/archive/3.7.2.tar.gz"
  sha256 "724f512b267af226066b48201e9596abba187f4cf1058841971bcb2ec42db6b0"
  version "3.7.2"

  head "https://codeberg.org/gaiasky/gaiasky.git", branch: "master"

  depends_on "openjdk" => :build   # JDK 25+ needed for compilation
  depends_on "openjdk"              # also needed at runtime

  # Gradle wrapper is bundled; no 'gradle' formula dependency needed

  def install
    ENV["GS_JAVA_VERSION_CHECK"] = "false"

    # Git setup for version detection
    if build.stable?
      # Stable builds come from a tarball (no .git directory).
      # Create minimal git history so git-describe produces a valid version string.
      system "git", "-c", "user.email=brew@localhost",
             "-c", "user.name=Homebrew",
             "init"
      system "git", "-c", "user.email=brew@localhost",
             "-c", "user.name=Homebrew",
             "add", "."
      system "git", "-c", "user.email=brew@localhost",
             "-c", "user.name=Homebrew",
             "commit", "-q", "-m", "initial"
      system "git", "tag", "#{version}"
    else
      # HEAD builds: Homebrew already cloned the full git repo.
      # Fetch tags so git-describe can find the nearest tag for the version string.
      system "git", "fetch", "--tags", "--unshallow" rescue nil
    end

    # Build the distribution package.
    # Disable Linux-only man-page generation to avoid a help2man dependency.
    system "./gradlew", "core:dist",
           "--no-daemon",
           "-x", "generateManPage",
           "-x", "gzipManPage"

    # Locate the produced distribution directory
    dist_dir = Pathname.glob("releases/gaiasky-*").first
    raise "Distribution directory not found in releases/" unless dist_dir

    # Install the entire distribution tree into libexec/
    # Structure: libexec/gaiasky  libexec/lib/  libexec/conf/  etc.
    libexec.install Dir[dist_dir/"*"]

    # Create a wrapper script in bin/ that sets JAVA_HOME and
    # delegates to the launcher.  The launcher resolves its own
    # path (BASH_SOURCE[0]) and finds libexec/lib/ correctly.
    (bin/"gaiasky").write_env_script libexec/"gaiasky",
      JAVA_HOME: Formula["openjdk"].opt_prefix

    # Create .app bundle
    app_name = "Gaia Sky"
    app = prefix/"#{app_name}.app"
    app_contents = app/"Contents"
    app_macos = app_contents/"MacOS"
    app_resources = app_contents/"Resources"
    app_macos.mkpath
    app_resources.mkpath

    # Launcher script that delegates to the Homebrew-installed gaiasky
    (app_macos/"gaiasky").write <<~SH
      #!/bin/bash
      exec "#{libexec}/gaiasky" "$@"
    SH
    app_macos/"gaiasky".chmod 0755

    # Info.plist
    (app_contents/"Info.plist").write <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleExecutable</key>
        <string>gaiasky</string>
        <key>CFBundleIdentifier</key>
        <string>space.gaiasky</string>
        <key>CFBundleName</key>
        <string>Gaia Sky</string>
        <key>CFBundleDisplayName</key>
        <string>Gaia Sky</string>
        <key>CFBundleVersion</key>
        <string>#{version}</string>
        <key>CFBundleShortVersionString</key>
        <string>#{version}</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>LSMinimumSystemVersion</key>
        <string>11.0</string>
        <key>NSHighResolutionCapable</key>
        <true/>
      </dict>
      </plist>
    XML

    # Create icons from macOS icon PNG file
    create_app_icons(app_resources)
  end

  def caveats
    <<~EOS
      To launch Gaia Sky from your Dock, Launchpad, or Spotlight, create a symlink:

        ln -sf "#{prefix}/Gaia Sky.app" /Applications

      Then open "Gaia Sky" as you would any other app.
      You can undo this later with:

        rm /Applications/Gaia\ Sky.app

      Gaia Sky requires at least OpenGL 3.3 and 4+ GB of RAM.
      On first launch, use the Dataset Manager to download
      the required base data pack and optional star catalogs.
    EOS
  end

  test do
    # Verify the launcher script exists and is executable
    assert_predicate bin/"gaiasky", :exist?
    assert_predicate bin/"gaiasky", :executable?

    # Check that the core JAR is in place
    assert_predicate libexec/"lib/gaiasky-core.jar", :exist?

    # Running with --help should exit 0 and show usage
    shell_output("#{bin}/gaiasky --help", 0)
  end

  # Livecheck block to detect new updates
  # Use codeberg releases
  # Do `brew livecheck gaiasky`
  livecheck do
    url "https://codeberg.org/gaiasky/gaiasky/releases"
    regex(%r{href=.*?/archive/v?(\d+(?:\.\d+)*(?:[.-]\d+)?)\.t}i)
  end

  private

  def create_app_icons(app_resources)
    iconset = app_resources/"icon.iconset"
    iconset.mkpath

    source = Pathname.new("assets/icon/gs_macos_512.png")
    unless source.exist?
      opoo "gs_macos_512.png not found, using gs_round_256.png from dist"
      source = libexec/"gs_round_256.png"
      return unless source.exist?
    end

    sizes = {
      "icon_16x16.png"       => 16,
      "icon_32x32.png"      => 32,
      "icon_128x128.png"    => 128,
      "icon_256x256.png"    => 256,
      "icon_512x512.png"    => 512,
      "icon_16x16@2x.png"   => 32,
      "icon_32x32@2x.png"   => 64,
      "icon_128x128@2x.png" => 256,
      "icon_256x256@2x.png" => 512,
    }
    sizes.each do |filename, px|
      system "sips", "-z", px.to_s, px.to_s,
             source.to_s,
             "--out", iconset/filename
    end

    system "iconutil", "-c", "icns",
           iconset.to_s,
           "--output", app_resources/"app.icns"
    iconset.rmtree
  end
end
