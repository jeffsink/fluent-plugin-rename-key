module Fluent::Plugin
  module RenameKeyUtil
    def create_rename_rules(conf)
      @rename_rules = []
      conf_rename_rules = conf.keys.select { |k| k =~ /^rename_rule(\d+)$/ }
      conf_rename_rules.sort_by { |r| r.sub('rename_rule', '').to_i }.each do |r|
        key_regexp, new_key = parse_rename_rule conf[r]

        if key_regexp.nil? || new_key.nil?
          raise Fluent::ConfigError, "Failed to parse: #{r} #{conf[r]}"
        end

        if @rename_rules.map { |r| r[:key_regexp] }.include? /#{key_regexp}/
          raise Fluent::ConfigError, "Duplicated rules for key #{key_regexp}: #{@rename_rules}"
        end

        @rename_rules << { key_regexp: /#{key_regexp}/, new_key: new_key }
        log.info "Added rename key rule: #{r} #{@rename_rules.last}"
      end
    end

    def create_replace_rules(conf)
      @replace_rules = []
      conf_replace_rules = conf.keys.select { |k| k =~ /^replace_rule(\d+)$/ }
      conf_replace_rules.sort_by { |r| r.sub('replace_rule', '').to_i }.each do |r|
        key_regexp, replacement = parse_replace_rule conf[r]

        if key_regexp.nil?
          raise Fluent::ConfigError, "Failed to parse: #{r} #{conf[r]}"
        end

        if replacement.nil?
          replacement = ""
        end

        if @replace_rules.map { |r| r[:key_regexp] }.include? /#{key_regexp}/
          raise Fluent::ConfigError, "Duplicated rules for key #{key_regexp}: #{@replace_rules}"
        end

        @replace_rules << { key_regexp: /#{key_regexp}/, replacement: replacement }
        log.info "Added replace key rule: #{r} #{@replace_rules.last}"
      end
    end

    def parse_rename_rule rule
      $~.captures if rule.match /^([^\s]+)\s+(.+)$/
    end

    def parse_replace_rule rule
      $~.captures if rule.match /^([^\s]+)(?:\s+(.+))?$/
    end

    def rename_key record
      new_record = {}

      record.each do |key, value|

        @rename_rules.each do |rule|
          match_data = key.match rule[:key_regexp]
          next unless match_data # next rule

          placeholder = get_placeholder match_data
          key = rule[:new_key].gsub /\${md\[\d+\]}/, placeholder
          break
        end

        if @deep_rename
          if value.is_a? Hash
            value = rename_key value
          elsif value.is_a? Array
            value = value.map { |v| v.is_a?(Hash) ? rename_key(v) : v }
          end
        end

        new_record[key] = value
      end

      new_record
    end

    def replace_key record
      new_record = {}

      record.each do |key, value|

        @replace_rules.each do |rule|
          match_data = key.match rule[:key_regexp]
          next unless match_data # next rule

          placeholder = get_placeholder match_data
          key = key.gsub rule[:key_regexp], rule[:replacement].gsub(/\${md\[\d+\]}/, placeholder)
          break
        end

        if @deep_rename
          if value.is_a? Hash
            value = replace_key value
          elsif value.is_a? Array
            value = value.map { |v| v.is_a?(Hash) ? replace_key(v) : v }
          end
        end

        new_record[key] = value
      end

      new_record
    end

    def get_placeholder match_data
      placeholder = {}

      match_data.to_a.each_with_index do |e, idx|
        placeholder["${md[#{idx}]}"] = e
      end

      placeholder
    end
  end
end
