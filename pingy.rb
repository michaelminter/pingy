require 'rubygems'
require 'bundler/setup'

Bundler.require

dir = File.dirname(__FILE__)
require dir + '/lib/pingy'
settings = File.exists?(dir + "/pingy.yml") ? YAML::load_file(dir + "/pingy.yml") : {}

PINGY = Pingy.new(settings)

# background thread for host checks
Thread.new do
  loop do
    sleep 30
    PINGY.timed_jobs
  end
end

before %r{/(host)?} do
  @info = PINGY.info
end

get '/' do
  @hosts = PINGY.get_all_hosts
  erb :index
end

get '/host' do
  if params[:ip] && params[:ip] =~ /^(\d{1,3}\.){3}\d{1,3}$/
    @ip = params[:ip]
    @details = PINGY.get_host(params[:ip])
    @host = PINGY.get_host_data(params[:ip])
    erb :host
  else
    return 404
  end
end

post '/collector' do
  content_type :xml
  request.body.rewind
  data = request.body.read
  PINGY.update(request.ip, data)  
end
