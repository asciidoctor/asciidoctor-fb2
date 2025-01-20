# frozen_string_literal: true

require_relative 'spec_helper'

describe Asciidoctor::FB2::Converter do
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
    expect(binary.content_type).to eq('image/jpeg')
    expect(binary.content).to eq(IO.read(fixture_file('wolpertinger.jpg'), mode: 'rb'))
  end

  it 'converts inline menu' do
    book, = convert <<~BOOK
      = Title
      :experimental:

      menu:File[Save]
      menu:Help[]
    BOOK

    body = book.bodies[0]
    expect(body.content).to include('<strong>File</strong>&#160;<strong>&#8250;</strong> <strong>Save</strong>')
    expect(body.content).to include('<strong>Help</strong>')
  end

  it 'converts sidebar' do
    book, = convert <<~BOOK
      = Title

      .Bzzzz
      ****
      Sidebar
      ****
    BOOK

    body = book.bodies[0]
    expect(body.content).to include('<p><strong>Bzzzz</strong>')
    expect(body.content).to include("<p>\nSidebar\n</p>")
  end

  it 'converts quote' do
    book, = convert <<~BOOK
      = Title

      [quote, Captain James T. Kirk, Star Trek IV: The Voyage Home]
      Everybody remember where we parked.
    BOOK

    body = book.bodies[0]
    expect(body.content).to include("<cite>\n<subtitle>Star Trek IV: The Voyage Home</subtitle>")
    expect(body.content).to include('<p>Everybody remember where we parked.</p>')
    expect(body.content).to include("<text-author>Captain James T. Kirk</text-author>\n</cite>")
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

  it 'converts inline index term' do
    book, = convert <<~BOOK
      = Title

      indexterm2:[Lancelot] was one of the Knights of the Round Table.
    BOOK

    body = book.bodies[0]
    expect(body.content).to include('Lancelot was one of the Knights of the Round Table.')
  end

  it 'converts inline callout' do
    book, = convert <<~BOOK
      = Title

      ----
      stuff <1>
      ----
      <1> words
    BOOK

    body = book.bodies[0]
    expect(body.content).to include('<p><code>stuff <strong>(1)</strong></code></p>')
    expect(body.content).to include('<p>1. words</p>')
  end

  it 'converts open block' do
    book, = convert <<~BOOK
      = Title

      --
      text
      --
    BOOK

    body = book.bodies[0]
    expect(body.content).to include('<p>
<p>
text
</p>')
  end

  it 'converts literal block' do
    book, = convert <<~BOOK
      = Title

      ....
      code
      more code
      ....
    BOOK

    body = book.bodies[0]
    expect(body.content).to include('<p><code>code</code></p>')
    expect(body.content).to include('<p><code>more code</code></p>')
  end

  it 'converts example block' do
    book, = convert <<~BOOK
      = Title

      .Example
      ====
      This is an example of an example block.
      ====
    BOOK

    body = book.bodies[0]
    expect(body.content).to include('<p><strong>Example:</strong></p>
<p>
This is an example of an example block.
</p>')
  end

  it 'converts floating title' do
    book, = convert <<~BOOK
      = Title

      [float]
      == lemme float
      ~~~~~~~~~~~~~~
    BOOK

    body = book.bodies[0]
    expect(body.content).to include('<subtitle id="_lemme_float">lemme float</subtitle>')
  end

  it 'converts thematic break' do
    book, = convert <<~BOOK
      = Title

      before

      '''

      after
    BOOK

    body = book.bodies[0]
    expect(body).not_to be_nil
  end

  it 'converts stem blocks' do
    book, = convert <<~BOOK
      = Title

      [asciimath,title=Math]
      ++++
      y=x^2 sqrt(4)
      ++++
    BOOK

    body = book.bodies[0]
    expect(body.content).to include('<p><code>y=x^2 sqrt(4)</code></p>')
  end

  it 'converts page break' do
    book, = convert <<~BOOK
      = Title

      <<<
    BOOK

    body = book.bodies[0]
    expect(body).not_to be_nil
  end
end
