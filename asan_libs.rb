#!/usr/bin/env ruby

require 'optparse'
require 'fileutils'
require 'tmpdir'
require 'shellwords'

$prefix = $cflags = $ldflags = $cc = $makeopts = nil
OptionParser.new do |opts|
  opts.banner = "Usage: asan_libs.rb --prefix=$RUBY_PREFIX"
  opts.on('--prefix=PREFIX') { $prefix = _1 }
  opts.on('--cflags=CFLAGS') { $cflags = _1 }
  opts.on('--ldflags=LDFLAGS') { $ldflags= _1 }
  opts.on('--cc=CC') { $cc = _1 }
  opts.on('--makeopts=MAKEOPTS') { $makeopts = _1 }
end.parse!
raise "--prefix must be specified" if $prefix.nil?


OPENSSL_VERSION = "3.3.0"
LIBYAML_VERSION = "0.2.5"

$cflags_args = []
$cflags_args << "CC=#{$cc}" if $cc
$cflags_args << "CFLAGS=#{$cflags}" if $cflags
$cflags_args << "LDFLAGS=#{$ldflags}" if $ldflags
$makeopts = Shellwords.split($makeopts || '')

def sh!(*args, **kwargs)
  puts "==> #{Shellwords.join(args)}"
  system(*args, **kwargs, exception: true) 
end

def chdir!(dir, &block)
  puts "==> cd #{File.realpath dir}" 
  Dir.chdir dir, &block
end

def rmglob!(what)
  Dir.glob(what).each do |file|
    puts "==> rm #{file}"
    FileUtils.rm_f file
  end
end

def compile_openssl
  # Make sure we compile OpenSSL to look for certificates in the same place that the
  # distribution provided OpenSSl would.
  openssldir = Shellwords.split(`openssl version -d`.match(/^\s*OPENSSLDIR:(.*)$/)[1].strip).first

  sh! *%w[curl -fsSLO], "https://www.openssl.org/source/openssl-#{OPENSSL_VERSION}.tar.gz"
  sh! *%w[tar -xf], "openssl-#{OPENSSL_VERSION}.tar.gz"
  chdir!("openssl-#{OPENSSL_VERSION}") do
    sh! './Configure', "--prefix=#{$prefix}", '--libdir=lib', "--openssldir=#{openssldir}",
      *%w[shared no-tests no-apps], *$cflags_args
    sh! 'make', *$makeopts
    # make install_sw will try and write config to OPENSSLDIR, which we don't want to do.
    sh! *%w[make install_dev], exception: true
    # OpenSSL make install_dev will also install static libraries, which we don't need
    rmglob! File.join($prefix, "lib/*.a")
  end
end

def compile_libyaml
  sh! *%w[curl -fsSLO], "http://pyyaml.org/download/libyaml/yaml-#{LIBYAML_VERSION}.tar.gz"
  sh! *%w[tar -xf], "yaml-#{LIBYAML_VERSION}.tar.gz"
  chdir!("yaml-#{LIBYAML_VERSION}") do
    sh! './configure', "--prefix=#{$prefix}", *%w[--disable-static --enable-shared], *$cflags_args
    sh! 'make', *$makeopts
    sh! 'make', 'install'
  end
end

Dir.mktmpdir('asan_libs') do |build_dir|
  Dir.chdir(build_dir) do
    compile_openssl
    compile_libyaml
  end
end
