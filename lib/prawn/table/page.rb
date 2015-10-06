module Prawn
  class Table
    # Page class are thinked to keep data and methods necesary to then render
    # table in multiple pages with header
    class Page
      attr_accessor :index, :width, :height, :cells, :closed, :header,
                    :header_rows

      def initialize i, header
        @index = i
        @cells = []
        @width = 0
        @height = 0
        @closed = false
        @header = header
        @header_rows = []
      end

      # I only handle header like boolean for now, since that is my case use,
      # but should be better handle another values that can be get header
      def cells_in_first_row
        # get cells in first row
        first_row = []
        cells.each do  |cell|
          if cell[0].row == 0
            first_row << cell
          end
        end
        first_row
      end

      def get_header
        if @header
          cells_in_first_row
        end
      end

      def add_header cells
        if @header
          @cells = cells
          @height += cells.last[0].height
        end
      end
    end
  end
end
