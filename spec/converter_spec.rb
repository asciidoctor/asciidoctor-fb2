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
    expect(body.content).to include('<strong>File</strong>&#160;<strong>&#8250;</strong> <strong>Save</strong>')
  end

  it 'converts verse' do
    book, = convert <<~BOOK
      = Title

      [verse, Janet Devlin, Working for the Man]
      _____
      Coffee cup
      Watching the hands of the clock
      Holding me, locked up
      Waiting for the sun to rise

      Red light
      Caught between day and night
      Can someone help me with this fight
      Against the Monday morning blues
      _____
    BOOK

    body = book.bodies[0]
    expect(body.content).to include("<poem>\n<title>Working for the Man</title>")
    expect(body.content).to include("<stanza>\n<v>Coffee cup</v>")
    expect(body.content).to include("<text-author>Janet Devlin</text-author>\n</poem>")
  end

  it 'converts inline line break' do
    book, = convert <<~BOOK
      = Title

      Rubies are red, +
      Topazes are blue.
    BOOK

    expect(book.bodies[0].content).to include("Rubies are red,\nTopazes are blue.")
  end

  it 'converts inline btn' do
    book, = convert <<~BOOK
      = Title
      :experimental:

      Press the btn:[OK] button when you are finished.
    BOOK

    expect(book.bodies[0].content).to include('[<strong>OK</strong>]')
  end

  it 'converts inline kbd' do
    book, = convert <<~BOOK
      = Title
      :experimental:

      kbd:[Ctrl+Shift+N]
    BOOK

    body = book.bodies[0]
    expect(body.content).to include('<strong>Ctrl</strong>+<strong>Shift</strong>+<strong>N</strong>')
  end
end
