task :default => [:compile]

task :compile do 
  sh "macrubyc -a x86_64 -o Coach.app/Contents/MacOS/Coach Coach.rb Preferences.rb MultiPart.rb Dribbble.rb"
end

task :deploy do
  sh "macruby_deploy --compile --embed --no-stdlib Coach.app"
end
