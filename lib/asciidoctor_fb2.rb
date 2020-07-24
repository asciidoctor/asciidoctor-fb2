# frozen_string_literal: true

require 'asciidoctor'
require 'asciidoctor/converter'
require 'fb2rb'

module Asciidoctor
  module FB2
    # Converts AsciiDoc documents to FB2 e-book formats
    class Converter < Asciidoctor::Converter::Base # rubocop:disable Metrics/ClassLength
      include ::Asciidoctor::Writer

      CSV_DELIMITER_REGEX = /\s*,\s*/.freeze

      register_for 'fb2'

      # @return [FB2rb::Book]
      attr_reader(:book)

      def initialize(backend, opts = {})
        super
        outfilesuffix '.fb2.zip'
      end

      # @param node [Asciidoctor::Document]
      def convert_document(node) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
        @book = FB2rb::Book.new
        @book.description.title_info.book_title = node.doctitle
        @book.description.title_info.lang = node.attr('lang', 'en')
        (node.attr 'keywords', '').split(CSV_DELIMITER_REGEX).each do |s|
          @book.description.title_info.keywords << s
        end
        (node.attr 'genres', '').split(CSV_DELIMITER_REGEX).each do |s|
          @book.description.title_info.genres << s
        end
        node.authors.each do |author|
          @book.description.title_info.authors << FB2rb::Author.new(
            author.firstname,
            author.middlename,
            author.lastname,
            nil,
            [],
            author.email.nil? ? [] : [author.email]
          )
        end

        if node.attr? 'series-name'
          series_name = node.attr 'series-name'
          series_volume = node.attr 'series-volume', 1
          @book.description.title_info.sequences << FB2rb::Sequence.new(series_name, series_volume)
        end

        date = node.attr('revdate') || node.attr('docdate')
        @book.description.title_info.date = @book.description.document_info.date = FB2rb::FB2Date.new(date, Date.parse(date))

        @book.description.document_info.id = node.attr('uuid', '')
        @book.description.document_info.version = node.attr('revnumber')
        @book.description.document_info.program_used = %(Asciidoctor FB2 #{VERSION} using Asciidoctor #{node.attr('asciidoctor-version')})

        publisher = node.attr('publisher')
        @book.description.document_info.publishers << publisher if publisher

        body = %(<section>
<title><p>#{node.doctitle}</p></title>
#{node.content}
</section>)
        @book.bodies << FB2rb::Body.new(nil, body)
        if node.document.footnotes
          notes = []
          node.document.footnotes.each do |footnote|
            notes << %(<section id="note-#{footnote.index}">
<title><p>#{footnote.index}</p></title>
<p>#{footnote.text}</p>
</section>)
          end
          @book.bodies << FB2rb::Body.new('notes', notes * "\n")
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
      def convert_listing(node)
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
        image_attrs = resolve_image_attrs(node, node.target)
        %(<image #{image_attrs * ' '}/>)
      end

      # @param node [Asciidoctor::Block]
      def convert_image(node)
        image_attrs = resolve_image_attrs(node, node.attr('target'))
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

      # @param node [Asciidoctor::AbstractNode]
      # @param target [String]
      def resolve_image_attrs(node, target) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        target = node.image_uri(target)
        unless Asciidoctor::Helpers.uriish?(target)
          out_dir = node.attr('outdir', nil, true) || doc_option(node.document, :to_dir)
          fs_path = File.join(out_dir, target)
          unless File.readable?(fs_path)
            base_dir = root_document(node.document).base_dir
            fs_path = File.join(base_dir, target)
          end

          if File.readable?(fs_path)
            @book.add_binary(target, fs_path)
            target = %(##{target})
          end
        end

        image_attrs = [%(l:href="#{target}")]
        image_attrs << %(alt="#{node.attr('alt')}") if node.attr? 'alt'
      end

      # @param node [Asciidoctor::Block]
      def convert_admonition(node)
        %(<p><strong>#{node.title || node.caption}:</strong>
#{node.content}
</p>)
      end

      # @param node [Asciidoctor::List]
      def convert_ulist(node)
        lines = []
        node.items.each do |item|
          lines << %(<p>• #{item.text}</p>)
          lines << %(<p>#{item.content}</p>) if item.blocks?
        end
        lines << '<empty-line/>' unless node.has_role?('last')
        lines * "\n"
      end

      # @param node [Asciidoctor::List]
      def convert_olist(node)
        lines = []
        node.items.each_with_index do |item, index|
          lines << %(<p>#{index + 1}. #{item.text}</p>)
          lines << %(<p>#{item.content}</p>) if item.blocks?
        end
        lines << '<empty-line/>' unless node.has_role?('last')
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

      # @param node [Asciidoctor::Table]
      def convert_table(node)
        lines = ['<table>']
        node.rows.to_h.each do |tsec, rows|
          next if rows.empty?
          rows.each do |row|
            lines << '<tr>'
            row.each do |cell|
              if tsec == :head
                cell_content = cell.text
              else
                case cell.style
                when :asciidoc
                  cell_content = cell.content
                when :literal
                  cell_content = %(<p><pre>#{cell.text}</pre></p>)
                else
                  cell_content = (cell_content = cell.content).empty? ? '' : %(<p>#{cell_content.join '</p>
<p>'}</p>)
                end
              end

              cell_tag_name = (tsec == :head || cell.style == :header ? 'th' : 'td')
              cell_colspan_attribute = cell.colspan ? %( colspan="#{cell.colspan}") : ''
              cell_rowspan_attribute = cell.rowspan ? %( rowspan="#{cell.rowspan}") : ''
              lines << %(<#{cell_tag_name}#{cell_colspan_attribute}#{cell_rowspan_attribute} halign="#{cell.attr 'halign'}" valign="#{cell.attr 'valign'}">#{cell_content}</#{cell_tag_name}>)
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
        output.write(target)
      end
    end
  end
end
