#
# Fluent
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#

require 'fluent/configurable'
require 'fluent/config/element'

module Fluent
  class SystemConfig
    include Configurable

    SYSTEM_CONFIG_PARAMETERS = [
      :root_dir, :log_level,
      :suppress_repeated_stacktrace, :emit_error_log_interval, :suppress_config_dump,
      :without_source, :rpc_endpoint, :enable_get_dump, :process_name,
      :file_permission, :dir_permission,
    ]

    config_param :root_dir, :string, default: nil
    config_param :log_level, default: nil do |level|
      Log.str_to_level(level)
    end
    config_param :suppress_repeated_stacktrace, :bool, default: nil
    config_param :emit_error_log_interval, :time, default: nil
    config_param :suppress_config_dump, :bool, default: nil
    config_param :without_source, :bool, default: nil
    config_param :rpc_endpoint, :string, default: nil
    config_param :enable_get_dump, :bool, default: nil
    config_param :process_name, default: nil
    config_param :file_permission, default: nil do |v|
      v.to_i(8)
    end
    config_param :dir_permission, default: nil do |v|
      v.to_i(8)
    end

    def self.create(conf)
      systems = conf.elements(name: 'system')
      return SystemConfig.new if systems.empty?
      raise Fluent::ConfigError, "<system> is duplicated. <system> should be only one" if systems.size > 1

      SystemConfig.new(systems.first)
    end

    def self.blank_system_config
      Fluent::Config::Element.new('<SYSTEM>', '', {}, [])
    end

    def self.overwrite_system_config(hash)
      older = defined?($_system_config) ? $_system_config : nil
      begin
        $_system_config = SystemConfig.new(Fluent::Config::Element.new('system', '', hash, []))
        yield
      ensure
        $_system_config = older
      end
    end

    def initialize(conf=nil)
      super()
      conf ||= SystemConfig.blank_system_config
      configure(conf)
    end

    def dup
      s = SystemConfig.new
      SYSTEM_CONFIG_PARAMETERS.each do |param|
        s.__send__("#{param}=", instance_variable_get("@#{param}"))
      end
      s
    end

    def apply(supervisor)
      system = self
      supervisor.instance_eval {
        SYSTEM_CONFIG_PARAMETERS.each do |param|
          param_value = system.send(param)
          next if param_value.nil?

          case param
          when :log_level
            @log.level = @log_level = param_value
          when :emit_error_log_interval
            @suppress_interval = param_value
          else
            instance_variable_set("@#{param}", param_value)
          end
        end
      }
    end

    module Mixin
      def system_config
        require 'fluent/engine'
        unless defined?($_system_config)
          $_system_config = nil
        end
        (instance_variable_defined?("@_system_config") && @_system_config) ||
          $_system_config || Fluent::Engine.system_config
      end

      def system_config_override(opts={})
        require 'fluent/engine'
        if !instance_variable_defined?("@_system_config") || @_system_config.nil?
          @_system_config = (defined?($_system_config) && $_system_config ? $_system_config : Fluent::Engine.system_config).dup
        end
        opts.each_pair do |key, value|
          @_system_config.send(:"#{key.to_s}=", value)
        end
      end
    end
  end
end
