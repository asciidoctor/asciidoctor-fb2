# frozen_string_literal: true

require_relative 'spec_helper'

describe 'asciidoctor-fb2' do
  it 'exits with 0 when prints version' do
    out, _, res = run_command asciidoctor_fb2_bin, '--version'
    expect(res.exitstatus).to eq(0)
    expect(out).to include %(Asciidoctor FB2 #{Asciidoctor::FB2::VERSION} using Asciidoctor #{Asciidoctor::VERSION})
  end

  it 'exits with 1 when given nonexistent path' do
    _, err, res = convert Pathname.new('/nonexistent')
    expect(res.exitstatus).to eq(1)
    expect(err).to match(%r{input file /nonexistent( is)? missing})
  end

  it 'converts README successfully' do
    in_file = 'README.adoc'
    out_file = temp_file 'README.fb2.zip'

    _, err, res = convert in_file, out_file
    expect(err).not_to include('ERROR')
    expect(res.exitstatus).to eq(0)
    expect(File).to exist(out_file)
  end

  def convert(in_file, out_file = nil)
    argv = asciidoctor_fb2_bin + [in_file.to_s]
    argv += ['-o', out_file.to_s] unless out_file.nil?
    run_command argv
  end
end
