class ShellcheckReadability < Formula
  desc "Bash readability checks that sit beside ShellCheck"
  homepage "https://github.com/yowainwright/shellcheck_readability"
  license "MIT"
  head "https://github.com/yowainwright/shellcheck_readability.git", branch: "main"

  depends_on "shellcheck" => :test
  depends_on "bash"

  def install
    libexec.install "bin", "lib"
    bin.write_exec_script libexec/"bin/shellcheck-readability"
  end

  test do
    (testpath/"example.sh").write <<~SHELL
      #!/usr/bin/env bash
      build_user() {
        if [[ -n "$USER" ]]; then
          printf '%s\\n' "$USER"
        fi
      }
    SHELL

    system bin/"shellcheck-readability", "check", testpath/"example.sh", "--exit-zero"
  end
end
