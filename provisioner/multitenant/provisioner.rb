#!/usr/bin/env ruby

require_relative 'tenantmanager'

module Loom
  class Provisioner
    attr_accessor :tenantmanagers, :provisioner_id

    def initialize()
      @tenantmanagers = {}
      pid = Process.pid
      host = Socket.gethostname.downcase
      @provisioner_id = "#{host}.#{pid}"
    end 

    def add_tenant(tenantmgr)
      if !tenantmgr.instance_of?(TenantManager)
        raise ArgumentError, "only instances of TenantManager can be added to provisioner", caller
      end
      # validate input
      id = tenantmgr.id
      puts "Adding/Editing tenant: #{id}"
      raise "cannot add a TenantManager without an id: #{tenantmgr.inspect}" if id.nil?

      # set provisionerId
      tenantmgr.provisioner_id = @provisioner_id

      if @tenantmanagers.key? id
        # edit tenant
        puts "Editing tenant: #{id}"
        @tenantmanagers[id].update(tenantmgr)
      else
        # new tenant
        puts "Adding new tenant: #{id}"
        tenantmgr.spawn
        @tenantmanagers[id] = tenantmgr
      end 
 
    end

    def delete_tenant(id)
      @tenantmanagers[id].delete
      @tenantmanagers.delete(id)
    end

    def status
      @tenantmanagers.each do |id, tm|
        tm.check_threads
      end
    end

    def heartbeat
      hb = {}
      hb['total'] = 1000
      hb['used'] = {}
      @tenantmanagers.each do |id, tm|
        hb['used'][id] = tm.num_workers
      end
      hb
    end

  end
end
