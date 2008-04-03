require "rubygems"
require "hoe"
require "./lib/pci4r.rb"

Hoe.new("pci4r", Pci4R::VERSION) do |p|
  p.name = "pci4r"
  p.developer 'Alex Vollmer', 'alex.vollmer@gmail.com'
  p.developer 'Mike Mondragon', 'mikemondragon@gmail.com'
  p.developer 'Jesse Cook', 'jesse@jesseclark.com'
  p.developer 'Sandro Paganotti', 'sandro.paganotti@gmail.com'
  p.summary = "A library of concepts covered in Toby Seagarn's 'Programming Collective Intelligence'"
  p.url = "http://github.com/alexvollmer/pci4r/tree/master"
  p.extra_deps = [
    ['activerecord', '>=2.0.0'],
    ['sqlite3-ruby', '>=1.2.1']
  ]
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new('spec_with_rcov') do |t|
  FileUtils.rm_rf('coverage')
  t.spec_files = FileList['spec/**/*_spec.rb']
  t.rcov = true
  t.rcov_opts = ['--html', '--xrefs', '--include lib', "--exclude spec,gems"]
  t.verbose = true
end
