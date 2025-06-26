require 'rbconfig'

module CLITest
  class << self
    BIN_DIR = RbConfig::CONFIG['bindir']

    DASH = "\u2500".dup.force_encoding 'utf-8'

    def chk_cli(cmd, regex)
      cmd_str = cmd[/\A[^ ]+/].ljust(10)
      cmd_path = "#{BIN_DIR}/#{cmd_str}".strip
      if File.exist? cmd_path.strip
        if RUBY_PLATFORM[/mingw|mswin/]
          unless File.exist?("#{cmd_path}.bat") || File.exist?("#{cmd_path}.cmd")
            return "#{cmd_str}❌   missing windows binstub"
          end
        end
        require 'open3'
        ret = ''.dup
        Open3.popen3(cmd) {|stdin, stdout, stderr, wait_thr|
          ret = stdout.read.strip
          ret = stderr.read.strip if ret.empty?
        }
        if ret[regex]
          "#{cmd_str}✅   #{$1}"
        else
          @error += 1
          "#{cmd_str}❌   version?"
        end
      else
        @error += 1
        "#{cmd_str}❌   missing binstub"
      end
    rescue => e
      @error += 1
      "#{cmd_str}❌   #{e.class} #{e.message}"
    end

    def run
      re_version = '(\d{1,2}\.\d{1,2}\.\d{1,2}(\.[a-z0-9.]+)?)'
      @error = 0
      puts "\n#{DASH * 5} CLI Test #{DASH * 17}"
      puts chk_cli("bundle -v",      /\A(?:Bundler version )?#{re_version}/)
      puts chk_cli("erb --version",  /\A#{re_version}/)
      puts chk_cli("gem --version",  /\A#{re_version}/)
      puts chk_cli("irb --version",  /\Airb +#{re_version}/)
      puts chk_cli("racc --version", /\Aracc version #{re_version}/)
      puts chk_cli("rake -V", /\Arake, version #{re_version}/)
      puts chk_cli("rbs -v" , /\Arbs #{re_version}/)
      puts chk_cli("rdbg -v", /\Ardbg #{re_version}/)
      puts chk_cli("rdoc -v", /\A#{re_version}/)
      puts chk_cli("test-unit --version", /\A(?:test-unit )?#{re_version}/)
      puts chk_cli("typeprof --version", /#{re_version}\z/)
      puts ''

      cli_desc =  %x[ruby -v].strip
      if cli_desc == RUBY_DESCRIPTION
        puts cli_desc, ''
      else
        puts "'ruby -v' doesn't match RUBY_DESCRIPTION\n" \
             "#{cli_desc}  (ruby -v)\n" \
             "#{RUBY_DESCRIPTION}  (RUBY_DESCRIPTION)", ''
        @error += 1
      end

      unless @error.zero?
        puts "bad exit"
        exit 1
      end
    end
  end
end
CLITest.run
