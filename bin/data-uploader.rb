#!/usr/bin/env ruby
# encoding: UTF-8
#
# Copyright 2012-2014, Continuuity, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'json'
require 'optparse'
require 'rest_client'
require 'tmpdir'
require 'fileutils'
require 'rubygems/package'
require 'zlib'

# ./data-uploader [-u http://localhost:55054] [-t superadmin] [-U admin] upload|stage|sync \ 
#   ./my/local/cookbooks/hadoop automatortypes/chef-solo/cookbooks/hadoop

def usage(optionparser)
  puts optionparser.banner
end

# Parse command line options.
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options] <action> <local-path> <remote-target>"
  opts.on('-u', '--uri URI', 'Server URI, defaults to ENV[\'LOOM_SERVER_URI\'] else "http://localhost:55054"') do |u|
    options[:uri] = u
  end
  opts.on('-t', '--tenant TENANT', 'Tenant, defaults to ENV[\'LOOM_TENANT\'] else "superadmin"') do |t|
    options[:tenant] = t
  end
  opts.on('-U', '--user USER', 'User, defaults to ENV[\'LOOM_API_USER\'] else "admin"') do |u|
    options[:user] = u
  end
  opts.separator ''
  opts.separator 'Required Arguments:'
  opts.separator '         <action>: one of upload, stage, or sync (sync can be dangerous)'
  opts.separator '     <local-path>: path to the local copy of the resource to upload'
  opts.separator '  <remote-target>: api path defining the resource'
  opts.separator ''
  opts.separator 'Example:'
  opts.separator "  #{$PROGRAM_NAME} -u http://localhost:55054 -t superadmin -U admin sync ./my/local/cookbooks/hadoop automatortypes/chef-solo/cookbooks/hadoop"
  opts.separator ''
end.parse!(ARGV)

server_uri = options[:uri] || ENV['LOOM_SERVER_URI'] || 'http://localhost:55054'
options[:uri] = server_uri

tenant = options[:tenant] || ENV['LOOM_TENANT'] || 'superadmin'
options[:tenant] = tenant

user = options[:user] || ENV['LOOM_API_USER'] || 'admin'
options[:user] = user

options[:action] = ARGV.shift
options[:path] = ARGV.shift
options[:target] = ARGV.shift

module Loom
  module DataUploader
    # class representing the resource to be uploaded
    class Resource
      attr_accessor :options
      def initialize(options)
        @options = options
        @headers = { :'X-Loom-UserID' => options[:user], :'X-Loom-TenantID' => options[:tenant] }
        RestClient.log = 'STDOUT'
      end

      def validate
        basic_validate
        validate_server_target
        validate_format
      end

      def basic_validate
        # action required
        unless @options[:action] =~ /^(upload|stage|sync)$/i
          fail 'missing or invalid action argument: must be one of "upload", "stage", or "sync"'
        end
        # path required
        if @options[:path].nil?
          fail 'missing local-path argument'
        elsif !File.exist?(@options[:path])
          fail "local-path argument supplied, but no such file or directory: #{@options[:path]}"
        end
        # api target required
        if @options[:target].nil?
          fail 'missing remote-target argument'
        else
          plugin_type, plugin_name, resource_type, resource_name = @options[:target].split('/')
          unless plugin_type =~ /^(automatortypes|providertypes)$/i
            fail "invalid remote-target argument, must begin with 'automatortypes/' or 'providertypes/': #{@options[:target]}"
          end
          @options[:plugin_type] = plugin_type
          if plugin_name.nil?
            fail "invalid remote-target argument, must be of format 'plugin_type/plugin_name/resource_type/resource_name'': #{@options[:target]}"
          end
          @options[:plugin_name] = plugin_name
          if resource_type.nil?
            fail "invalid remote-target argument, must be of format 'plugin_type/plugin_name/resource_type/resource_name'': #{@options[:target]}"
          end
          @options[:resource_type] = resource_type
          if resource_name.nil?
            fail "invalid remote-target argument, must be of format 'plugin_type/plugin_name/resource_type/resource_name'': #{@options[:target]}"
          end
          @options[:resource_name] = resource_name
        end
      end

      def validate_server_connectivity
        uri = %W( #{@options[:uri]} status ).join('/')
        resp = RestClient.get(uri, @headers)
        unless resp.code == 200
          fail "non-ok response code #{resp.code} from server at: #{uri}"
        end
      end

      # query server api for given plugin_type and ensure the resource can be uploaded
      def validate_server_target
        validate_server_connectivity
        uri = %W( #{@options[:uri]} v1/loom #{@options[:plugin_type]} #{@options[:plugin_name]}).join('/')
        resp = RestClient.get(uri, @headers)
        if resp.code == 200
          resp_plugin = JSON.parse(resp.to_str)
          if resp_plugin.key?('resourceTypes') && resp_plugin['resourceTypes'].key?(@options[:resource_type])
            resp_resource = resp_plugin['resourceTypes'][@options[:resource_type]]
            if resp_resource.key?('format')
              @expected_format = resp_resource['format']
            else
              fail "plugin plugin #{@options[:plugin_type]} #{@options[:plugin_name]}, resource #{@options[:resource_type]} does not have a registered format"
            end
          else
            fail "plugin #{@options[:plugin_type]} #{@options[:plugin_name]} has not registered resource type #{@options[:resource_type]} at server #{uri}"
          end
        else
          fail "non-ok response code #{resp.code} from server at: #{:uri}"
        end
      end

      def validate_format
        # expected_format discovered by validate_server_target
        case @expected_format
        when 'archive'
          unless local_path_is_tgz?
            unless local_path_is_directory?
              fail "server resource registered as archive, but local-path argument is not a directory or .tgz archive: #{@options[:path]}"
            end
          end
        when 'file'
          fail "server resource registered as file, but local-path argument is not a file: #{@options[:path]}" unless local_path_is_file?
        else
          fail "unknown expected format from server: #{@expected_format}"
        end
        @options[:format] = @expected_format
      end

      def local_path_is_file?
        File.file?(@options[:path])
      end

      def local_path_is_tgz?
        File.file?(@options[:path]) && @options[:path] =~ /\.(tgz|tar\.gz)$/i
      end

      def local_path_is_directory?
        File.directory?(@options[:path])
      end

      def upload
        case @options[:format]
        when 'archive'
          if local_path_is_tgz?
            upload_file_resource
          else
            upload_archive_resource
          end
        when 'file'
          upload_file_resource
        else
          # this should get caught in validate
          fail "unknown expected format: #{@options[:format]}"
        end
      end

      def upload_archive_resource
        payload = gzip(tar_with_resourcename(@options[:path]))
        upload_resource(payload)
      end

      def upload_file_resource
        payload = File.new(@options[:path], 'rb')
        upload_resource(payload)
      end

      def upload_resource(payload)
        uri = %W( #{@options[:uri]} v1/loom #{@options[:plugin_type]} #{@options[:plugin_name]} #{@options[:resource_type]} #{@options[:resource_name]}).join('/')
        resp = RestClient.post(uri, payload, @headers)
        if resp.code == 200
          resp_obj = JSON.parse(resp.to_str)
          puts "upload successful, uri: #{uri}, version: #{resp_obj['version']}"
          @upload_results = resp_obj
        else
          fail "non-ok response code #{resp.code} from server at: #{uri}"
        end
      end

      def stage
        version = @upload_results['version']
        uri = %W( #{@options[:uri]} v1/loom #{@options[:plugin_type]} #{@options[:plugin_name]} #{@options[:resource_type]} #{@options[:resource_name]} versions #{version} stage).join('/')
        resp = RestClient.post(uri, nil, @headers)
        if resp.code == 200
          puts "stage successful: #{uri}"
        else
          fail "stage request at #{uri} failed with code #{resp.code}"
        end
      end

      # syncing can be dangerous!
      def sync
        uri = %W( #{@options[:uri]} v1/loom/sync).join('/')
        resp = RestClient.post(uri, nil, @headers)
        if resp.code == 200
          puts 'sync successful'
        else
          fail "non-ok response code: #{resp.code} from server for sync request: #{uri}"
        end
      end

      # modified from http://old.thoughtsincomputation.com/posts/tar-and-a-few-feathers-in-ruby
      # Creates a tar file in memory recursively
      # from the given path.
      #
      # Returns a StringIO whose underlying String
      # is the contents of the tar file.
      def tar_with_resourcename(path)
        tarfile = StringIO.new('')
        Gem::Package::TarWriter.new(tarfile) do |tar|
          Dir[File.join(path, '**/*')].each do |file|
            mode = File.stat(file).mode
            relative_file = file.sub(/^#{Regexp.escape path}\/?/, '')
            relative_file = File.join(@options[:resource_name], relative_file)

            if File.directory?(file)
              tar.mkdir relative_file, mode
            else
              tar.add_file relative_file, mode do |tf|
                File.open(file, 'rb') { |f| tf.write f.read }
              end
            end
          end
        end
        tarfile.rewind
        tarfile
      end

      # gzips the underlying string in the given StringIO,
      # returning a new StringIO representing the
      # compressed file.
      def gzip(tarfile)
        gz = StringIO.new('')
        z = Zlib::GzipWriter.new(gz)
        z.write tarfile.string
        z.close # this is necessary!
        # z was closed to write the gzip footer, so
        # now we need a new StringIO
        StringIO.new gz.string
      end
    end
  end
end

ldr = Loom::DataUploader::Resource.new(options)
ldr.validate

case ldr.options[:action]
when /upload/i
  ldr.upload
when /stage/i
  ldr.upload
  ldr.stage
when /sync/i
  ldr.upload
  ldr.stage
  ldr.sync
end
