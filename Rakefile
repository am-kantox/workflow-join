# encoding: UTF-8
require 'rubygems'

require 'bundler'
require 'bundler/setup'
require 'bundler/gem_tasks'

require 'rspec/core/rake_task'

begin
  Bundler.setup(:default, :development, :test)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end

desc 'Tests w/ActiveRecord'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = '-Ispec'
  #  spec.rcov = true
end

desc 'Tests wo/ActiveRecord'
RSpec::Core::RakeTask.new(:spec_simple) do |spec|
  ENV['USE_SIMPLE_PERSISTENCE'] = 'true'
  spec.rspec_opts = '-Ispec'
  #  spec.rcov = true
end

task default: [:spec, :spec_simple]
