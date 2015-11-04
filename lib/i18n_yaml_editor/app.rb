# encoding: utf-8

require 'psych'
require 'yaml'
require 'active_support/all'

require 'i18n_yaml_editor'
require 'i18n_yaml_editor/web'
require 'i18n_yaml_editor/store'
require 'i18n_yaml_editor/core_ext'

module I18nYamlEditor
  # the App
  class App
    def initialize(path, port = 5050)
      @path = File.expand_path(path)
      @port = port
      @store = Store.new
      I18nYamlEditor.app = self
    end

    attr_accessor :store

    def start
      $stdout.puts " * Loading translations from #{@path}"
      load_translations

      $stdout.puts ' * Creating missing translations'
      store.create_missing_keys

      $stdout.puts ' * Starting web editor at port 5050'
      Rack::Server.start app: Web, Port: (@port || 5050)
    end

    def load_translations
      default_files = Dir[@path + '/**/*.yml']
      files = File.directory?(@path) ? default_files : File.read(@path).split
      files.each do |file|
        if File.exist?(file)
          yaml = YAML.load_file(file)
          store.from_yaml(yaml, file)
        else
          $stderr.puts "File #{file} not found."
        end
      end
    end

    def save_translations(translations)
      files = files(translations: translations)

      files.each do|file, yaml|
        File.open(file, 'w', encoding: 'utf-8') do |f|
          f.puts normalize(yaml)
        end
      end
    end

    def files(translations: {})
      store.to_yaml.select do |_, i18n_hash|
        translations.keys.any? do |i18n_key|
          key_in_i18n_hash? i18n_key, i18n_hash
        end
      end
    end

    def key_in_i18n_hash?(i18n_key, i18n_hash)
      i18n_key.split('.').inject(i18n_hash) do |hash, k|
        begin
          hash[k]
        rescue
          {}
        end
      end.present?
    end

    def normalize(yaml)
      i18n_yaml = yaml.with_indifferent_access.to_hash_recursive.to_yaml
      process = i18n_yaml.split(/\n/).reject { |e| e == '' }[1..-1]
      new_line_after_2_indents(process) * "\n"
    end

    def new_line_after_2_indents(process)
      yaml_ary = []
      process.each_with_index do |line, idx|
        yaml_ary << line
        foo(yaml_ary, process, line, idx)
      end
      yaml_ary
    end

    def foo(yaml_ary, process, line, idx)
      return if process[idx + 1].nil?
      this_line_spcs = line[/\A\s*/].length
      next_line_spcs = process[idx + 1][/\A\s*/].length
      yaml_ary << '' if this_line_spcs - next_line_spcs > 2
    end
  end
end
