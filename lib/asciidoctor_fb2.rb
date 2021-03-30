# frozen_string_literal: true

require 'asciidoctor'
require 'asciidoctor/converter'
require 'fb2rb'
require 'mime/types'

module Asciidoctor
  module FB2
    DATA_DIR = File.expand_path(File.join(__dir__, '..', 'data'))

    # Converts AsciiDoc documents to FB2 e-book formats
    class Converter < Asciidoctor::Converter::Base # rubocop:disable Metrics/ClassLength
      include ::Asciidoctor::Writer

      CSV_DELIMITER_REGEX = /\s*,\s*/.freeze
      IMAGE_ATTRIBUTE_VALUE_RX = /^image:{1,2}(.*?)\[(.*?)\]$/.freeze

      register_for 'fb2'

      # @return [FB2rb::Book]
      attr_reader(:book)

      def initialize(backend, opts = {})
        super
        outfilesuffix '.fb2.zip'
      end

      # @param node [Asciidoctor::Document]
      def convert_document(node) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        @book = FB2rb::Book.new
        @book.add_stylesheet('text/css', File.join(DATA_DIR, 'fb2.css'))

        document_info = @book.description.document_info
        title_info = @book.description.title_info

        title_info.book_title = node.doctitle
        title_info.lang = node.attr('lang', 'en')
        (node.attr 'keywords', '').split(CSV_DELIMITER_REGEX).each do |s|
          title_info.keywords << s
        end
        (node.attr 'genres', '').split(CSV_DELIMITER_REGEX).each do |s|
          title_info.genres << s
        end
        node.authors.each do |author|
          title_info.authors << FB2rb::Author.new(
            first_name: author.firstname,
            middle_name: author.middlename,
            last_name: author.lastname,
            emails: author.email.nil? ? [] : [author.email]
          )
        end

        if node.attr? 'series-name'
          series_name = node.attr 'series-name'
          series_volume = node.attr 'series-volume', 1
          title_info.sequences << FB2rb::Sequence.new(name: series_name, number: series_volume)
        end

        date = node.attr('revdate') || node.attr('docdate')
        fb2date = FB2rb::FB2Date.new(display_value: date, value: Date.parse(date))
        title_info.date = document_info.date = fb2date

        unless (cover_image = node.attr('front-cover-image')).nil?
          cover_image = Regexp.last_match(1) if cover_image =~ IMAGE_ATTRIBUTE_VALUE_RX
          cover_image_path = node.image_uri(cover_image)
          register_binary(node, cover_image_path, 'image')
          title_info.coverpage = FB2rb::Coverpage.new(images: [%(##{cover_image_path})])
        end

        document_info.id = node.attr('uuid', '')
        document_info.version = node.attr('revnumber')
        document_info.program_used = %(Asciidoctor FB2 #{VERSION} using Asciidoctor #{node.attr('asciidoctor-version')})

        publisher = node.attr('publisher')
        document_info.publishers << publisher if publisher

        body = %(<section>
<title><p>#{node.doctitle}</p></title>
#{node.content}
</section>)
        @book.bodies << FB2rb::Body.new(content: body)
        unless node.document.footnotes.empty?
          notes = []
          node.document.footnotes.each do |footnote|
            notes << %(<section id="note-#{footnote.index}">
<title><p>#{footnote.index}</p></title>
<p>#{footnote.text}</p>
</section>)
          end
          @book.bodies << FB2rb::Body.new(name: 'notes', content: notes * "\n")
        end
        @book
      end

      # @param node [Asciidoctor::Section]
      def convert_preamble(node)
        mark_last_paragraph(node)
        node.content
      end

      # @param node [Asciidoctor::Section]
      def convert_section(node)
        mark_last_paragraph(node)
        if node.parent == node.document && node.document.doctype == 'book'
          %(<section id="#{node.id}">
<title><p>#{node.title}</p></title>
#{node.content}
</section>)
        else
          %(<subtitle id="#{node.id}">#{node.title}</subtitle>
#{node.content})
        end
      end

      # @param _node [Asciidoctor::Block]
      def convert_toc(_node)
        ''
      end

      # @param node [Asciidoctor::Block]
      def convert_paragraph(node)
        lines = [
          '<p>',
          node.content,
          '</p>'
        ]
        lines << '<empty-line/>' unless node.has_role?('last')
        lines * "\n"
      end

      # @param node [Asciidoctor::Block]
      def convert_quote(node)
        citetitle = node.attr('citetitle')
        citetitle_tag = citetitle.nil_or_empty? ? '' : %(<subtitle>#{citetitle}</subtitle>)

        author = node.attr('attribution')
        author_tag = author.nil_or_empty? ? '' : %(<text-author>#{node.attr('attribution')}</text-author>)

        %(<cite>
#{citetitle_tag}
<p>#{node.content}</p>
#{author_tag}
</cite>)
      end

      # @param node [Asciidoctor::Block]
      def convert_verse(node)
        body = node.content&.split("\n\n")&.map do |stanza|
          %(<stanza>\n<v>#{stanza.split("\n") * "</v>\n<v>"}</v>\n</stanza>)
        end&.join("\n")

        citetitle = node.attr('citetitle')
        citetitle_tag = citetitle.nil_or_empty? ? '' : %(<title>#{citetitle}</title>)

        author = node.attr('attribution')
        author_tag = author.nil_or_empty? ? '' : %(<text-author>#{node.attr('attribution')}</text-author>)

        %(<poem>
#{citetitle_tag}
#{body}
#{author_tag}
</poem>)
      end

      # @param node [Asciidoctor::Block]
      def convert_listing(node)
        convert_literal(node)
      end

      # @param node [Asciidoctor::Block]
      def convert_literal(node)
        lines = []
        node.content.split("\n").each do |line|
          lines << %(<p><code>#{line}</code></p>)
        end
        lines << '<empty-line/>' unless node.has_role?('last')
        lines * "\n"
      end

      (QUOTE_TAGS = { # rubocop:disable Style/MutableConstant
        monospaced: ['<code>', '</code>'],
        emphasis: ['<emphasis>', '</emphasis>'],
        strong: ['<strong>', '</strong>'],
        double: ['“', '”'],
        single: ['‘', '’'],
        superscript: ['<sup>', '</sup>'],
        subscript: ['<sub>', '</sub>'],
        asciimath: ['<code>', '</code>'],
        latexmath: ['<code>', '</code>']
      }).default = ['', '']

      # @param node [Asciidoctor::Inline]
      def convert_inline_quoted(node)
        open, close = QUOTE_TAGS[node.type]
        %(#{open}#{node.text}#{close})
      end

      # @param node [Asciidoctor::Inline]
      def convert_inline_menu(node)
        caret = '&#160;<strong>&#8250;</strong> '
        menu = node.attr('menu')
        menuitem = node.attr('menuitem')
        submenus = node.attr('submenus') * %(</b>#{caret}<b>)

        result = %(<strong>#{menu}</strong>)
        result += %(#{caret}<strong>#{submenus}</strong>) unless submenus.nil_or_empty?
        result += %(#{caret}<strong>#{menuitem}</strong>) unless menuitem.nil_or_empty?

        result
      end

      # @param node [Asciidoctor::Inline]
      def convert_inline_break(node)
        node.text
      end

      # @param node [Asciidoctor::Inline]
      def convert_inline_button(node)
        %([<strong>#{node.text}</strong>])
      end

      # @param node [Asciidoctor::Inline]
      def convert_inline_kbd(node)
        %(<strong>#{node.attr('keys') * '</strong>+<strong>'}</strong>)
      end

      # @param node [Asciidoctor::Inline]
      def convert_inline_anchor(node) # rubocop:disable Metrics/MethodLength
        case node.type
        when :xref
          %(<a l:href="#{node.target}">#{node.text}</a>)
        when :link
          %(<a l:href="#{node.target}">#{node.text}</a>)
        when :ref
          %(<a id="#{node.id}"></a>)
        when :bibref
          unless (reftext = node.reftext)
            reftext = %([#{node.id}])
          end
          %(<a id="#{node.id}"></a>#{reftext})
        else
          logger.warn %(unknown anchor type: #{node.type.inspect})
          nil
        end
      end

      # @param node [Asciidoctor::Inline]
      def convert_inline_footnote(node)
        index = node.attr('index')
        %(<a l:href="#note-#{index}" type="note">[#{index}]</a>)
      end

      # @param node [Asciidoctor::Inline]
      def convert_inline_image(node)
        image_attrs = register_binary(node, node.image_uri(node.target), 'image')
        %(<image #{image_attrs * ' '}/>)
      end

      # @param node [Asciidoctor::Inline]
      def convert_inline_indexterm(node)
        node.type == :visible ? node.text : ''
      end

      # @param node [Asciidoctor::Block]
      def convert_image(node)
        image_attrs = register_binary(node, node.image_uri(node.attr('target')), 'image')
        image_attrs << %(title="#{node.captioned_title}") if node.title?
        image_attrs << %(id="#{node.id}") if node.id
        %(<p><image #{image_attrs * ' '}/></p>)
      end

      # @param doc [Asciidoctor::Document]
      # @return [Asciidoctor::Document]
      def root_document(doc)
        doc = doc.parent_document until doc.parent_document.nil?
        doc
      end

      def determine_mime_type(filename, media_type)
        mime_types = MIME::Types.type_for(filename)
        mime_types.delete_if { |x| x.media_type != media_type }
        mime_types.empty? ? nil : mime_types[0].content_type
      end

      # @param node [Asciidoctor::AbstractNode]
      # @param target [String]
      def register_binary(node, target, media_type) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        unless Asciidoctor::Helpers.uriish?(target)
          out_dir = node.attr('outdir', nil, true) || doc_option(node.document, :to_dir)
          fs_path = File.join(out_dir, target)
          unless File.readable?(fs_path)
            base_dir = root_document(node.document).base_dir
            fs_path = File.join(base_dir, target)
          end

          if File.readable?(fs_path)
            # Calibre fails to load images if they contain path separators
            target.sub!('/', '_')
            target.sub!('\\', '_')

            mime_type = determine_mime_type(target, media_type)
            @book.add_binary(target, fs_path, mime_type)
            target = %(##{target})
          end
        end

        image_attrs = [%(l:href="#{target}")]
        image_attrs << %(alt="#{node.attr('alt')}") if node.attr? 'alt'
      end

      # @param node [Asciidoctor::Block]
      def convert_admonition(node)
        lines = [%(<p><strong>#{node.title || node.caption}:</strong>
#{node.content}
</p>)]
        lines << '<empty-line/>' unless node.has_role?('last')
        lines * "\n"
      end

      # @param node [Asciidoctor::Block]
      def convert_sidebar(node)
        title_tag = node.title.nil_or_empty? ? '' : %(<p><strong>#{node.title}</strong></p>)
        %(#{title_tag}
#{node.content})
      end

      # @param node [Asciidoctor::List]
      def convert_ulist(node)
        lines = []
        @stack ||= []

        node.items.each do |item|
          @stack << '•'
          lines << %(<p>#{@stack * ' '} #{item.text}</p>)
          lines << %(<p>#{item.content}</p>) if item.blocks?
          @stack.pop
        end

        lines << '<empty-line/>' unless node.has_role?('last') || !@stack.empty?
        lines * "\n"
      end

      # @param node [Asciidoctor::List]
      def convert_olist(node) # rubocop:disable Metrics/AbcSize
        lines = []
        @stack ||= []
        node.items.each_with_index do |item, index|
          @stack << %(#{index + 1}.)
          lines << %(<p>#{@stack * ' '} #{item.text}</p>)
          lines << %(<p>#{item.content}</p>) if item.blocks?
          @stack.pop
        end
        lines << '<empty-line/>' unless node.has_role?('last') || !@stack.empty?
        lines * "\n"
      end

      # @param node [Asciidoctor::List]
      def convert_dlist(node) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        lines = ['<table>']
        node.items.each do |terms, dd|
          lines << '<tr>'
          lines << '<td>'
          first_term = true
          terms.each do |dt|
            lines << %(<empty-line/>) unless first_term
            lines << '<p>'
            lines << '<strong>' if node.option?('strong')
            lines << dt.text
            lines << '</strong>' if node.option?('strong')
            lines << '</p>'
            first_term = false
          end
          lines << '</td>'
          lines << '<td>'
          if dd
            lines << %(<p>#{dd.text}</p>) if dd.text?
            lines << dd.content if dd.blocks?
          end
          lines << '</td>'
          lines << '</tr>'
        end
        lines << '</table>'
        lines << '<empty-line/>' unless node.has_role?('last')
        lines * "\n"
      end

      # @param cell [Asciidoctor::Table::Cell]
      def get_cell_content(cell) # rubocop:disable Metrics/MethodLength
        case cell.style
        when :asciidoc
          cell.content
        when :emphasis
          %(<emphasis>#{cell.text}</emphasis>)
        when :literal
          %(<code>#{cell.text}</code>)
        when :monospaced
          %(<code>#{cell.text}</code>)
        when :strong
          %(<strong>#{cell.text}</strong>)
        else
          cell.text
        end
      end

      # @param node [Asciidoctor::Table]
      def convert_table(node) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        lines = []
        lines << %(<subtitle>#{node.captioned_title}</subtitle>) if node.title?
        lines << '<table>'
        node.rows.to_h.each do |tsec, rows|
          next if rows.empty?

          rows.each do |row|
            lines << '<tr>'
            row.each do |cell|
              cell_content = get_cell_content(cell)
              cell_tag_name = (tsec == :head || cell.style == :header ? 'th' : 'td')
              cell_attrs = [
                %(halign="#{cell.attr 'halign'}"),
                %(valign="#{cell.attr 'valign'}")
              ]
              cell_attrs << %(colspan="#{cell.colspan}") if cell.colspan
              cell_attrs << %(rowspan="#{cell.rowspan}") if cell.rowspan
              lines << %(<#{cell_tag_name} #{cell_attrs * ' '}>#{cell_content}</#{cell_tag_name}>)
            end
            lines << '</tr>'
          end
        end
        lines << '</table>'
        lines << '<empty-line/>' unless node.has_role?('last')
        lines * "\n"
      end

      # @param root [Asciidoctor::AbstractNode]
      def mark_last_paragraph(root)
        return unless (last_block = root.blocks[-1])

        last_block = last_block.blocks[-1] while last_block.context == :section && last_block.blocks?
        last_block.add_role('last') if last_block.context == :paragraph
        nil
      end

      # @param output [FB2rb::Book]
      def write(output, target)
        if target.respond_to?(:end_with?) && target.end_with?('.zip')
          output.write_compressed(target)
        else
          output.write_uncompressed(target)
        end
      end
    end
  end
end
