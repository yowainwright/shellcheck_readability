class ShellcheckLegibility < Formula
  desc "Bash legibility checks that sit beside ShellCheck"
  homepage "https://github.com/yowainwright/shellcheck_legibility"
  license "MIT"
  head "https://github.com/yowainwright/shellcheck_legibility.git", branch: "main"

  depends_on "bash"

  def install
    libexec.install "bin", "lib"
    bin.write_exec_script libexec/"bin/shellcheck-legibility"
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

    system bin/"shellcheck-legibility", "check", testpath/"example.sh", "--exit-zero"
  end
end
