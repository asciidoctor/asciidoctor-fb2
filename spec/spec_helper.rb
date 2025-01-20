# frozen_string_literal: true

require 'asciidoctor_fb2'
require 'open3'

RSpec.configure do |config|
  config.before do
    FileUtils.rm_r temp_dir, force: true, secure: true
  end

  config.after do
    FileUtils.rm_r temp_dir, force: true, secure: true
  end

  def bin_script(name, opts = {})
    path = Gem.bin_path (opts.fetch :gem, 'asciidoctor-fb2'), name
    [Gem.ruby, path]
  end

  def asciidoctor_fb2_bin
    bin_script 'asciidoctor-fb2'
  end

  def run_command(cmd, *args)
    if cmd.is_a?(Array)
      args.unshift(*cmd)
      cmd = args.shift
    end
    env_override = { 'RUBYOPT' => nil }
    Open3.capture3 env_override, cmd, *args
  end

  def temp_dir
    Pathname.new(__dir__).join 'temp'
  end

  def temp_file(*path)
    temp_dir.join(*path)
  end

  def fixtures_dir
    Pathname.new(__dir__).join 'fixtures'
  end

  def fixture_file(*path)
    fixtures_dir.join(*path)
  end

  def convert(input, opts = {}) # rubocop:disable Metrics/AbcSize
    opts[:backend] = 'fb2'
    opts[:header_footer] = true
    opts[:mkdirs] = true
    opts[:safe] = Asciidoctor::SafeMode::UNSAFE unless opts.key? :safe
    return Asciidoctor.convert(input, opts) unless input.is_a?(Pathname)

    opts[:to_dir] = temp_dir.to_s unless opts.key?(:to_dir) || opts.key?(:to_file)
    result = Asciidoctor.convert_file(input.to_s, opts)
    output = Pathname.new(result.attr('outfile'))
    book = FB2rb::Book.read_compressed(output)
    [book, output]
  end
end
