{ pkgs, lib, ... }:

{
  # Java 21 LTS runtime & Scala 3 + sbt environment
  languages.java = {
    enable = true;
    jdk.package = pkgs.temurin-bin-21;
  };

  languages.scala = {
    enable = true;
    sbt.enable = true;
  };

  packages = with pkgs; [
    scala-cli # Fast runner, single-file scripts, and prototyping
    scalafmt  # Code formatter
    metals    # Scala Language Server
    git
    jq
  ];

  enterShell = ''
    # Auto-validate project if build.sbt or project.scala exists
    if [ -f build.sbt ]; then
      echo "📦 Validating sbt build configuration..."
      sbt update --warn 2>/dev/null || echo "💡 Run 'sbt compile' to build project dependencies."
    elif [ -f project.scala ]; then
      echo "📦 Validating scala-cli project configuration..."
      scala-cli compile . --quiet 2>/dev/null || echo "💡 Run 'scala-cli run .' to execute."
    else
      echo "⚠️  Warning: No 'build.sbt' or 'project.scala' found."
      echo "   💡 Initialize your Scala & ZIO project:"
      echo "      • Quick sbt + ZIO starter: run 'sbt new zio/zio-seed.g8'"
      echo "      • Fast Scala-CLI script: create 'Main.scala' with '//> using dep dev.zio::zio:2.1.9'"
      echo "   Whenever 'build.sbt' or 'project.scala' is created, direnv will auto-sync!"
    fi

    echo "🔴 Scala $(scala-cli version 2>/dev/null | head -n1 || echo '3.x') | Java $(java -version 2>&1 | head -n1 | awk -F '"' '{print $2}') | sbt ready!"
    echo "💡 Quality check: 'scalafmt .' | REPL: 'scala-cli repl' | Build: 'sbt compile' | Watch: 'sbt ~run'"
  '';
}
