# frozen_string_literal: true

require 'asciidoctor'
require 'asciidoctor/converter'
require 'fb2rb'

module Asciidoctor
  module FB2
    # Converts AsciiDoc documents to FB2 e-book formats
    class Converter < Asciidoctor::Converter::Base
      include ::Asciidoctor::Writer

      register_for 'fb2'

      def initialize(backend, opts = {})
        super
        outfilesuffix '.fb2.zip'
      end

      def convert_document(node) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        @book = FB2rb::Book.new
        @book.description.title_info.book_title = node.doctitle
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
        node.content
        @book
      end

      def add_chapter(node)
        # TODO: article vs book, multipart book
        return nil if node.parent != node.document

        @book.bodies << FB2rb::Body.new(node.title, node.content)
      end

      def convert_preamble(node)
        node.content if add_chapter(node).nil?
      end

      def convert_section(node)
        %(<section><title>#{node.title}</title>#{node.content}</section>) if add_chapter(node).nil?
      end

      def convert_paragraph(node)
        %(<p>#{node.content}</p>)
      end

      def convert_listing(node)
        %(<p><code>#{node.content}</code></p>)
      end

      def convert_inline_quoted(node)
        %(<code>#{node.text}</code>)
      end

      def convert_inline_image(node)
        %(<img xlink:href="#{node.target}" />)
      end

      def write(output, target)
        output.write(target)
      end
    end
  end
end
