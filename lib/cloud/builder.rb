module Cloud
  NETWORK_NAME = ENV["NETWORK_NAME"] || "s202926-net"
  SUBNET_NAME  = ENV["SUBNET_NAME"] || "s202926-subnet"
  SUBNET_RANGE = ENV["SUBNET_RANGE"] || "192.168.114.0/24"
  DNS_NAMESERVER = ENV["DNS_NAMESERVER"] || "10.7.0.3"
  ROUTER_NAME = ENV["ROUTER_NAME"] || "s202926-router"
  PUB_KEY_FILE= ENV["PUB_KEY_FILE"] || "#{ENV["HOME"]}/.ssh/id_rsa.pub"
  KEYPAIR_NAME = ENV["KEYPAIR_NAME"] || "s202926-key"
  INSTANCE_PREFIX = ENV["INSTANCE_PREFIX"] || "s202926vm-"
  INSTANCE_FLAVOR = ENV["INSTANCE_FLAVOR"] || "3"
  VM_IMAGE = ENV["VM_IMAGE"] || "ubuntu-trusty"
  timeout = ENV["MAX_WAIT_TIME"] || 180 ; MAX_WAIT_TIME = timeout.to_i

  class EnvError < RuntimeError
  end
  
  class Builder
    def initialize
      @router = nil
   
      check_openstack_env
      @quantum = setup_connection "network"

      @network = Network.new @quantum
      @subnetwork = SubNetwork.new @quantum, @network
      @tenant_id = @network.tenant_id
      @router = Router.new @quantum, @subnetwork

      @compute = setup_connection "compute"
      @instances = Instance.all @compute
    end

    def build(nb_instances)
      KeyPair.import @compute
      SecRule.new @compute, "-1"
      SecRule.new @compute, "22"

      if @instances.length != 0
	puts "A cloud is existing add #{nb_instances} to it"
	Instance::last_id = @instances.length
      end

      @new_instances = []
      (0...nb_instances).each do
        instance = Instance.new(@compute)
        @instances << instance
        @new_instances << instance
      end
      Instance.wait_all_active(@compute, @instances)
      @new_instances.each do |i|
        i.set_floating_ip(@quantum, FloatingIp.get(@compute))
      end
      Instance.wait_all_ssh(@compute, @instances)
      
      puts "VMs successfully created, cluster is booting"
    end
    
    def purge
      if @instances == nil or @instances.length == 0
        puts "No VM to destroy"
      end
      @instances.each do |i| i.delete end
      Instance.wait_all_death(@compute, @instances)
      @router.delete
      @subnetwork.delete
      @network.delete
    end

    def write_hostsfile(path, opts = {})
      if opts[:type] == "ansible"
        puts "Write Ansible hosts file: #{path}"
        @instances.sort_by!{ |i| i.name.split("-")[1].to_i }
        File.open path, "w" do |f|
	  f.puts "[controller]\n#{@instances.first.name} ansible_ssh_host=#{@instances.first.ip} ansible_ssh_user=ubuntu\n\n"
          f.puts "[agents]\n"
          @instances.each_with_index do |i, index|
	    next if index == 0
            f.puts "#{i.name} ansible_ssh_host=#{i.ip} ansible_ssh_user=ubuntu"
          end   
        end
      elsif opts[:type] == "mpi"
        puts "Write MPI machinefile file: #{path}"
        File.open path, "w" do |f|
          @instances.each do |i|
            f.puts "ubuntu@#{i.ip}"
          end   
        end
      else
        raise "To type specified"
      end
    end

    private 

    def check_openstack_env
      puts "Validation of the Openstack environment variables"
      %w(OS_USERNAME OS_PASSWORD OS_AUTH_URL OS_TENANT_NAME).each do |var|
        if ENV[var].nil?
          raise EnvError.new "ENV[#{var}] is undefined"
        end
      end
    end
    
    def setup_connection(type)
      c = OpenStack::Connection.create({
        :username => ENV["OS_USERNAME"],
        :password => ENV["OS_PASSWORD"],
        :auth_url => ENV["OS_AUTH_URL"],
        :authtenant_name => ENV["OS_TENANT_NAME"],
        :api_key => ENV["OS_PASSWORD"],
        :auth_method=> "password",
        :service_type=> type
      })
      c.connection.service_path = "/"
      if type == "compute"
        c.connection.service_path = "/v2/#{@tenant_id}"
      end
      return c
    end
  end
end
