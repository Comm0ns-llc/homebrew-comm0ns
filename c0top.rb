class C0top < Formula
  desc "Comm0ns Dashboard CLI & TUI"
  homepage "https://github.com/Comm0ns-llc/c0top"
  url "https://github.com/Comm0ns-llc/c0top/archive/refs/tags/v1.0.0.tar.gz"
  version "1.0.0"
  sha256 "6f6b1d3ce28601a4025214d44c95cb56b9bd698da94c515cbf5893a7b8701be2"
  license "MIT"

  depends_on "cmake" => :build
  depends_on "python@3.11"

  def install
    # Build C++ TUI
    cd "comm0ns_cpp_tui" do
      system "cmake", "-S", ".", "-B", "build"
      system "cmake", "--build", "build", "-j4"
      libexec.install "build/comm0ns_tui"
    end

    # Install Python auth logic
    libexec.install "src"

    # Install Python wrapper script
    (libexec/"c0top_launcher.py").write <<~EOS
      #!/usr/bin/env python3
      import os
      import sys
      from pathlib import Path

      project_root = Path(__file__).parent.resolve()
      sys.path.insert(0, str(project_root))

      from src.tui_auth import ensure_tui_auth_session, AuthError

      SUPABASE_URL = "https://qoahsyycabfohobvxrzg.supabase.co"
      SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFvYWhzeXljYWJmb2hvYnZ4cnpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc4MDI3NzIsImV4cCI6MjA4MzM3ODc3Mn0.3TSx8SqJU7v7RmZb0Nhb29OQA2Nnmj2VH-Sp7l3NhEE"

      def main():
          url = os.environ.get("SUPABASE_URL", SUPABASE_URL)
          key = os.environ.get("SUPABASE_ANON_KEY", SUPABASE_ANON_KEY)
          
          print("Checking Discord authentication...")
          force_login = "--force-login" in sys.argv
          try:
              session = ensure_tui_auth_session(
                  force_login=force_login,
                  timeout_sec=180,
                  supabase_url=url,
                  supabase_key=key,
              )
              user = session.get("user", {})
              user_name = user.get("user_metadata", {}).get("full_name") or user.get("email") or "User"
              print(f"Authenticated successfully as {user_name}")
          except AuthError as e:
              print(f"Authentication error: {e}", file=sys.stderr)
              sys.exit(1)
          except KeyboardInterrupt:
              print("\\nAuthentication cancelled.")
              sys.exit(130)

          os.environ["SUPABASE_URL"] = url
          os.environ["SUPABASE_KEY"] = key

          tui_bin = project_root / "comm0ns_tui"
          if not tui_bin.exists():
              print(f"Error: C++ TUI binary not found at {tui_bin}", file=sys.stderr)
              sys.exit(1)

          print("Launching Comm0ns TUI...")
          os.execv(str(tui_bin), [str(tui_bin)])

      if __name__ == "__main__":
          main()
    EOS

    # Create the executable wrapper script in bin
    bin.write_exec_script (libexec/"c0top_launcher.py")
    mv bin/"c0top_launcher.py", bin/"c0top"
  end

  test do
    system "#{bin}/c0top", "--help"
  end
end
