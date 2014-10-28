# encoding: utf-8

module Prawn
  class Table

    # This class knows everything about splitting an array of cells
    class SplitCells

      def initialize(cells, options = {})
        @cells = cells
        @current_row_number = options[:current_row_number]
      end

      attr_accessor :cells

      def cells_new_page
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