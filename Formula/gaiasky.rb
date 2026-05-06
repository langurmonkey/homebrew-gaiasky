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
  end

  def caveats
    <<~EOS
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
    regex(%r{href=.*?/archive/?(\d+(?:\.\d+)+)\.t}i)
  end
end
