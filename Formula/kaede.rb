class Kaede < Formula
  desc "Statically-typed compiled language for writing concise, fast servers"
  homepage "https://github.com/itto-hiramoto/kaede"
  url "https://github.com/itto-hiramoto/kaede/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "263ce19cd152ce17c9d092072263679ccaedb93e31240fbf181fc7cf00e3a4f2"
  license any_of: ["Apache-2.0", "MIT"]
  head "https://github.com/itto-hiramoto/kaede.git", branch: "main"

  depends_on "cmake"      => :build
  depends_on "pkg-config" => :build
  depends_on "rust"       => :build
  depends_on "llvm@17"
  depends_on "openssl@3"

  # Mirrors the library/bdwgc submodule. Keep the commit and sha256 in sync with
  # `git -C library/bdwgc rev-parse HEAD` on each release.
  resource "bdwgc" do
    url "https://github.com/ivmai/bdwgc/archive/0f54cebfdc91b192e3ad253aa9a8ed801e985bb7.tar.gz"
    sha256 "e7040c02007482cd32c0c46bbcf8523580d2a93656abe53a2336582732cdf07f"
  end

  def install
    (buildpath/"library/bdwgc").install resource("bdwgc")

    ENV.prepend_path "PATH",            Formula["llvm@17"].opt_bin
    ENV.prepend_path "PKG_CONFIG_PATH", Formula["openssl@3"].opt_lib/"pkgconfig"
    ENV["LLVM_SYS_170_PREFIX"] = Formula["llvm@17"].opt_prefix

    # install.py lays out bin/, lib/, third_party/ under its --prefix; stage that
    # under libexec so the wrapper below can point KAEDE_DIR at it.
    system "python3", "./install.py", "--prefix=#{libexec}"

    # The kaede binary reads $KAEDE_DIR to locate libkd, autoload sources, and
    # third_party/bdwgc; if unset it falls back to a path baked in when kaede
    # itself was built, which is meaningless on the user's machine. It also
    # shells out to llc/opt from the keg-only llvm@17 when compiling user
    # programs. Wrap the binary so both are wired up without user setup.
    (bin/"kaede").write_env_script libexec/"bin/kaede",
                                   KAEDE_DIR: libexec,
                                   PATH:      "#{Formula["llvm@17"].opt_bin}:$PATH"
  end

  test do
    (testpath/"hello.kd").write <<~KAEDE
      fun main() {
          println("hello, world!")
      }
    KAEDE
    system bin/"kaede", "--version"
    system bin/"kaede", testpath/"hello.kd", "-o", testpath/"hello"
    assert_equal "hello, world!", shell_output(testpath/"hello").strip
  end
end
