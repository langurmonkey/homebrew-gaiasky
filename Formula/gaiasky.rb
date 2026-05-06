# Formula/gaiasky.rb
class Gaiasky < Formula
  desc "Real-time 3D Universe platform with support for more than a billion objects"
  homepage "https://gaiasky.space"
  license "MPL-2.0"

  url "https://codeberg.org/gaiasky/gaiasky/archive/3.7.2.tar.gz"
  sha256 "724f512b267af226066b48201e9596abba187f4cf1058841971bcb2ec42db6b0"
  version "3.7.2"

  depends_on "openjdk" => :build   # JDK 25+ needed for compilation
  depends_on "openjdk"              # also needed at runtime

  # Gradle wrapper is bundled; no 'gradle' formula dependency needed

  def install
    ENV["GS_JAVA_VERSION_CHECK"] = "false"

    # Create minimal git history so git-based version detection works.
    # This ensures the distribution dir is named e.g. "gaiasky-v3.6.7.abc1234"
    # and the version file inside the JAR is correct.
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
end
