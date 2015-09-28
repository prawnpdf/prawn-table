module Prawn
  class Table
    # Page class are thinked to keep data and methods necesary to then render
    # table in multiple pages with header
    class Page
      attr_accessor :index, :width, :height, :cells, :closed, :header_rows

      def initialize i
        @index = i
        @cells = []
        @width = 0
        @height = 0
        @closed = false
        @header_rows = []
      end
    end
  end
end
