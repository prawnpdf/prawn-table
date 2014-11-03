# encoding: utf-8

require_relative 'table/splittable/split_cell'
require_relative 'table/splittable/split_cells'

module Prawn
  # This class is an extension to Prawn::Table
  # It allows the final row on a page to be split accross two pages
  class TableSplittable < Table

    # option passed to TableSplittable indicating that this table
    # should split final rows on a page if needed.
    attr_accessor :split_cells_across_pages


    # this is the main function that is called from Prawn::Table.draw
    # it processes all the cells, positioning them onto the table
    # and splitting them if needed
    def process_cells(ref_bounds, started_new_page_at_row, offset)

      cells_this_page = []
      split_cells = []
      splitting = false

      @cells.each do |cell|

        # should we split cells?
        if split_cells?(cell)
          # the main work of splitting the cells of a row (here only for one cell) between two pages
          cell, split_cells, cells_this_page, splitting, offset, started_new_page_at_row = process_split_cell(cell, offset, ref_bounds, splitting, started_new_page_at_row, split_cells, cells_this_page)
        elsif start_new_page?(cell, offset, ref_bounds) 
          # draw cells on the current page and then start a new one
          # this will also add a header to the new page if a header is set
          # reset array of cells for the new page
          cells_this_page, offset = ink_and_draw_cells_and_start_new_page(cells_this_page, cell)

          # remember the current row for background coloring
          started_new_page_at_row = cell.row
        end

        # Set background color, if any.
        cell = set_background_color(cell, started_new_page_at_row)
        
        if splitting
          # remember this cell
          split_cells.push cell
        else
          # add the current cell to the cells array for the current page
          cells_this_page << [cell, [cell.relative_x, cell.relative_y(offset)]]
        end
      end

      cells_this_page, offset = print_split_cells_on_final_page(split_cells, cells_this_page, offset, splitting)

      cells_object = Prawn::Table::SplitCells.new(cells_this_page, cells_this_page: true, table: self)
      cells_this_page = cells_object.adjust_height_of_final_cells(header_rows, started_new_page_at_row)

      return cells_this_page, offset
    end

    # takes care of the splitting and printing for a single cell
    def process_split_cell(cell, offset, ref_bounds, splitting, started_new_page_at_row, split_cells, cells_this_page)
      @row_to_split ||= -1
      @original_height ||= 0

      max_available_height = (cell.y + offset) - ref_bounds.absolute_bottom

       # should the row be split?
      if start_new_page?(cell, offset, ref_bounds, true) && max_available_height > 0
        @row_to_split = cell.row
        @original_height = cell.height
        splitting = true
      end

      # split cell content and adjust height of cell
      cell = Prawn::Table::SplitCell.new(cell).split(@row_to_split, max_available_height)

      # reset @row_to_split variable if we're in the next row
      @row_to_split = -1 if have_we_passed_the_row_to_be_split?(cell, @row_to_split)

      if print_split_cells?(split_cells, cell, max_available_height, started_new_page_at_row)

        cells_this_page, offset = print_split_cells(cells_this_page, split_cells, cell, offset, @original_height)

        split_cells = []
        splitting=false
        
        # remember the current row for background coloring
        started_new_page_at_row = cell.row
      end

      return cell, split_cells, cells_this_page, splitting, offset, started_new_page_at_row
    end

    # the final page needs some special treatment
    def print_split_cells_on_final_page(split_cells, cells_this_page, offset, splitting)
      print_split_cells_single_page(split_cells, cells_this_page, offset)

      if splitting
        # draw cells on the current page and then start a new one
        # this will also add a header to the new page if a header is set
        # reset array of cells for the new page
        cells_this_page, offset = ink_and_draw_cells_and_start_new_page(cells_this_page, @cells.last)

        # draw split cells on to the new page
        print_split_cells_single_page(split_cells, cells_this_page, offset, new_page: true, current_row: @cells.last.row)
      end

      return cells_this_page, offset
    end

    # are all cells in this row normal text cells without any fancy formatting we can't easily handle when splitting cells
    def only_plain_text_cells(row_number)
      row(row_number).each do |cell|
        return true if cell.is_a?(Prawn::Table::Cell::SpanDummy)

        if !cell.is_a?(Prawn::Table::Cell::Text) ||
           cell.rotate ||
           cell.rotate_around ||
           cell.leading || 
           cell.single_line
          return false
        end
      end
      return true
    end

    # "print" cells that have been split onto a page
    # print means - add it to the cells_this_page array
    # this function will be used multiple times, once on the old and once on the new page
    def print_split_cells_single_page(split_cells, cells_this_page, offset, hash={})
      cells_object = Prawn::Table::SplitCells.new(split_cells, table: self, new_page: hash[:new_page])
      cells_object.adjust_content_for_new_page if hash[:new_page]
      
      @max_cell_height = cells_object.max_cell_heights
      cells_object.adjust_height_of_cells
      
      cells_object.cells.each do |split_cell|
        cell = Prawn::Table::SplitCell.new(split_cell, cells_object)
        
        cells_this_page << cell.print(offset, @max_cell_height_cached, @final_cell_last_page)

        row(split_cell.row).reduce_y(-2000) if cell.move_cells_off_canvas?
      end

      @max_cell_height_cached = cells_object.max_cell_heights(true)
      return (@max_cell_height.values.max || 0)
    end

    # ink and draw cells, then start a new page
    def ink_and_draw_cells_and_start_new_page(cells_this_page, cell, split_cells=false, offset=false)
      # print any remaining cells to be split
      print_split_cells_single_page(split_cells, cells_this_page, offset) if offset

      @final_cell_last_page = split_cells.last if split_cells

      super
    end

    private

    # should we split cells at all?
    def split_cells?(cell)
      (defined?(@split_cells_across_pages) && @split_cells_across_pages && only_plain_text_cells(cell.row))
    end

    # is it time to print the split cells?
    def print_split_cells?(split_cells, cell, max_available_height, started_new_page_at_row)
      cell_height = cell.calculate_height_ignoring_span

      (cell_height > max_available_height && 
       cell.row > started_new_page_at_row && 
       !cell.is_a?(Prawn::Table::Cell::SpanDummy) && 
       !split_cells.empty?)
    end

    # are we in the row after the one that has to be split?
    def have_we_passed_the_row_to_be_split?(cell, row_to_split)
      (row_to_split > -1 && cell.row > row_to_split && !cell.is_a?(Prawn::Table::Cell::SpanDummy))
    end

    # print the cells that have been split
    # it will acutally write/print the cells onto the old page
    # for the new page print only means adding it to the cells_this_page variable
    def print_split_cells(cells_this_page, split_cells, cell, offset, original_height)
      # recalculate / resplit content for split_cells array
      # this may be necessary because a cell that spans multiple rows did not
      # know anything about needed height changes in subsequent rows when the text was split
      # e.g. original n+1 lines where able to be printed in the remaining space, however
      # a splitting of a later row resulted in a table that was smaller than the theoretical
      # maximum that was used in the original calculation (for example due to the padding)
      # thus the last line can't be printed because there is only space for n lines
      cells_object = Prawn::Table::SplitCells.new(split_cells, table: self, current_row_number: cell.row)
      
      # O(n^2) on the cells about to be split
      # maybe we can improve this at some point in the future
      cells_object.resplit_content

      # draw cells on the current page and then start a new one
      # this will also add a header to the new page if a header is set
      # reset array of cells for the new page
      cells_this_page, offset = ink_and_draw_cells_and_start_new_page(cells_this_page, cell, cells_object.cells_old_page, offset)

      # any remaining cells to be split will have been split by the ink_and_draw_cells_and_start_new_page command

      # draw split cells on to the new page
      split_cell_height = print_split_cells_single_page(cells_object.cells_new_page, cells_this_page, offset - original_height, new_page: true, current_row: cell.row)
      offset -= split_cell_height

      return cells_this_page, offset
    end
  end
end
