class Pingy
  def initialize(settings={})
    @settings = {
      :host => "127.0.0.1", # redis host
      :port => 6379,        # redis port
      :dc => "default"      # datacenter
    }  

    settings.each { |k,v| @settings[k.to_sym] = v }

    @info = { :pid => Process.pid, :started_at => Time.now, :uptime => "0 seconds" }    
    @db = Redis.new(:host => @settings[:host], :port => @settings[:port])

    # db lookup methods
    @m = {
      :hosts => "#{@settings[:dc]}|hosts",
      :host_data => "#{@settings[:dc]}|host_data"
    }
  end

  def add_host(ip, stats={}, data={})
    host = get_host(ip)
    if host.has_key?(:service_status)
      stats[:service_status] = host[:service_status]
    end

    @db.hset(@m[:hosts], ip, Marshal.dump(stats))
    add_host_data(ip, data)
  end

  def add_host_data(ip, data={})
    @db.hset(@m[:host_data], ip, Marshal.dump(data))
  end

  def del_host(ip)
    @db.hdel(@m[:hosts], ip)
    del_host_data(ip)
  end

  def del_host_data(ip)
    @db.hdel(@m[:host_data], ip)
  end

  def get_all_hosts
    if @db.exists(@m[:hosts])
      all = {}
      @db.hgetall(@m[:hosts]).each do |host,stats|
        all[host] = Marshal.restore(stats)
      end

      all
    end
  end

  def get_hosts
    @db.hkeys(@m[:hosts])
  end

  def get_host(ip)
    Marshal.restore(@db.hget(@m[:hosts], ip)) if @db.hexists(@m[:hosts], ip)
  end

  def get_host_data(ip)
    Marshal.restore(@db.hget(@m[:host_data], ip)) if @db.hexists(@m[:host_data], ip)
  end

  def get_hosts
    @db.hkeys(@m[:hosts])
  end

  def info
    @info[:uptime] = "#{Time.now - @info[:started_at]} seconds"
    @info
  end

  def log(msg) 
    puts "#{Time.now} - #{msg}"
  end

  def timed_jobs
    set_host_status
    set_service_status
  end

  def set_host_status
    time = Time.now

    get_all_hosts.each do |host, stats|
      # For each host check the status against last updated and poll times.
      # If it exceeds poll time then ping the host to see if its actually down.
      log("checking #{stats[:hostname]} status")
      if (time - stats[:last_update]) > stats[:poll].to_i # add 10 seconds 
	log("#{stats[:hostname]} is down")
        stats[:host_status] = "down"
        add_host(host, stats)
      end
    end    
  end

  def set_service_status
    get_hosts.each do |ip|
      service_status = "up"
      data = get_host_data(ip)
      data["services"]["service"].each do |service|
        service_status = "down" if service["status"] != "0"
      end

      update_status(ip,service_status)
    end
  end

  def update(ip, xml)
    data = Crack::XML.parse(xml)

    if data.has_key?("monit")
      values = { 
        :hostname => data["monit"]["server"]["localhostname"],
        :uptime => data["monit"]["server"]["uptime"],
        :poll => data["monit"]["server"]["poll"],
        :last_update => Time.now,
        :host_status => "up",
        :service_status => ""
      }

      add_host(ip, values, data["monit"])
    end
  end

  def update_status(ip,service_status)
    host = get_host(ip)
    unless host.empty?
      host[:service_status] = service_status
      set_host(host)
    end
  end
end
