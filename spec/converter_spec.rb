# frozen_string_literal: true

require_relative 'spec_helper'

describe 'asciidoctor-fb2' do
  it 'produces stable output for reproducible books' do
    out_file1 = temp_file 'book1.fb2.zip'
    out_file2 = temp_file 'book2.fb2.zip'
    convert fixture_file('reproducible.adoc'), to_file: out_file1.to_s
    sleep 2
    convert fixture_file('reproducible.adoc'), to_file: out_file2.to_s
    expect(FileUtils.compare_file(out_file1.to_s, out_file2.to_s)).to be true
  end
end
