# encoding: utf-8

module Prawn
  class Table

    # This class knows everything about splitting an array of cells
    class SplitCells

      def initialize(cells, options = {})
        @cells = cells
        @current_row_number = options[:current_row_number]
        @new_page = options[:new_page]
        @table = options[:table]
        compensate_offset_for_height = 0
      end

      # allow this class to access the rows of the table
      def rows(row_spec)
        table.rows(row_spec)
      end
      alias_method :row, :rows

      attr_accessor :cells

      # the table associated with this instance
      attr_reader :table

      # change content to the one needed for the new page
      def adjust_content_for_new_page
        cells.each do |cell|
          cell.content = cell.content_new_page
        end
      end

      def adjust_height_of_cells
        @cells.each do |cell|
          unless cell.is_a?(Prawn::Table::Cell::SpanDummy)
            # if multiple cells of multiple rows are split it may happen that the cell
            # holding the text (and which will be rendered) is from an earlier row than
            # the last row on the last page (and thus the first row on the new page)
            # in this case set the height of this cell to the first line of the new page
            # otherwise just take the newely calculated row height
            first_row_new_page = max_cell_heights.keys.min || 0

            if cell.row < first_row_new_page
              cell.height = max_cell_heights[first_row_new_page]
              # puts "@@@ cell #{cell.row}/#{cell.column} height=#{cell.height} max_cell_heights=#{max_cell_heights}(ts 203)"
            else
              cell.height = max_cell_heights[cell.row]
              # puts "@@@ cell #{cell.row}/#{cell.column} height=#{cell.height} (ts 206)"
            end
          end
        end
      end

      # calculate the maximum height of each row
      def max_cell_heights(force_reload = false)
        # cache the result
        return @max_cell_heights if !force_reload && defined? @max_cell_heights

        @max_cell_heights = Hash.new(0)
        cells.each do |cell|
          puts "@@@ cell #{cell.row}/#{cell.column} content=#{cell.content} content_new_page=#{cell.content_new_page} content_new_page.class=#{cell.content_new_page.class}"

          # if we are on the new page, change the content of the cell
          # cell.content = cell.content_new_page if hash[:new_page]

          # calculate the height of the cell includign any cells it may span
          respect_original_height = true unless @new_page
          cell_height = cell.calculate_height_ignoring_span(respect_original_height)

          # account for the height of any rows this cell spans (new page)
          rows = cell.dummy_cells.map { |dummy_cell| dummy_cell.row if dummy_cell.row_dummy? }.uniq.compact
          rows.each do |row_number|
            cell_height -= row(row_number).height
          end

          @max_cell_heights[cell.row] = cell_height if @max_cell_heights[cell.row] < cell_height unless cell.content.nil? || cell.content.empty? 
        end
        puts "cell 0/0 cell 27/0 cell 28/0 reloading = @max_cell_heights=#{@max_cell_heights}"
        @max_cell_heights
      end
      
      attr_accessor :compensate_offset_for_height

      def compensate_offset
        (max_cell_height.values.max || 0) - compensate_offset_for_height
      end

      # remove any cells from the cells array that are not needed on the new page
      def calculate_cells_new_page
        # is there some content to display coming from the last row on the last page?
        # found_some_content_in_the_last_row_on_the_last_page = false
        # cells.each do |split_cell|
        #   next unless split_cell.row == last_row_number_last_page
        #   found_some_content_in_the_last_row_on_the_last_page = true unless split_cell.content_new_page.nil? || split_cell.content_new_page.empty?
        # end

        cells_new_page = []
        cells.each do |split_cell|
          next if irrelevant_cell?(split_cell)

          # all tests passed. print it - meaning add it to the array
          cells_new_page.push split_cell
        end

        cells_new_page
      end

      private

      # cells that aren't located in the last row and that don't span
      # the last row with an attached dummy cell are irrelevant
      # for the splitting process
      def irrelevant_cell?(cell)
        # don't print cells that don't span anything and that 
        # aren't located in the last row
        return true if cell.row < last_row_number_last_page &&
                       cell.dummy_cells.empty? && 
                       !cell.is_a?(Prawn::Table::Cell::SpanDummy)

        # if they do span multiple cells, check if at least one of them
        # is located in the last row of the last page
        if !cell.dummy_cells.empty?
          found_a_cell_in_the_last_row_on_the_last_page = false
          cell.dummy_cells.each do |dummy_cell|
            found_a_cell_in_the_last_row_on_the_last_page = true if dummy_cell.row == last_row_number_last_page
          end
          return true unless found_a_cell_in_the_last_row_on_the_last_page
        end
        return false
      end

      # the row number of the last row on the last page
      def last_row_number_last_page
        @current_row_number - 1
      end

    end
  end
end