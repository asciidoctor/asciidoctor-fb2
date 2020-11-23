# frozen_string_literal: true

require_relative 'spec_helper'

describe 'asciidoctor-fb2' do # rubocop:disable Metrics/BlockLength
  it 'produces stable output for reproducible books' do
    out_file1 = temp_file 'book1.fb2.zip'
    out_file2 = temp_file 'book2.fb2.zip'
    convert fixture_file('reproducible.adoc'), to_file: out_file1.to_s
    sleep 2
    convert fixture_file('reproducible.adoc'), to_file: out_file2.to_s
    expect(FileUtils.compare_file(out_file1.to_s, out_file2.to_s)).to be true
  end

  it 'adds cover image' do
    book, = convert fixture_file('cover.adoc')
    coverpage = book.description.title_info.coverpage
    expect(coverpage).not_to be_nil
    expect(coverpage.images).to eq(['#wolpertinger.jpg'])

    binary = book.binaries[0]
    expect(binary).not_to be_nil
    expect(binary.id).to eq('wolpertinger.jpg')
    expect(binary.content).to eq(IO.read(fixture_file('wolpertinger.jpg'), mode: 'rb'))
  end

  it 'converts inline menu' do
    book, = convert <<~BOOK
      = Title
      :experimental:

      To save the file, select menu:File[Save].
    BOOK

    body = book.bodies[0]
    expect(body).not_to be_nil
    expect(body.content).to include('<strong>File</strong>&#160;<strong>&#8250;</strong> <strong>Save</strong>')
  end
end
