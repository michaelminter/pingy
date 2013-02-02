app_dir = File.dirname(__FILE__)
worker_processes 1
working_directory app_dir
listen 8080, :tcp_nopush => false
pid "#{app_dir}/unicorn.pid"
stdout_path "#{app_dir}/unicorn.log"
stderr_path "#{app_dir}/unicorn.log"
preload_app true
GC.respond_to?(:copy_on_write_friendly=) and
  GC.copy_on_write_friendly = true
