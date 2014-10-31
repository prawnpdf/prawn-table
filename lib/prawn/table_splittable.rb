# encoding: utf-8

require_relative 'table/splittable/split_cell'
require_relative 'table/splittable/split_cells'

module Prawn
  class TableSplittable < Table

    # option passed to TableSplittable indicating that this table
    # should split final rows on a page if needed.
    attr_accessor :split_cells_across_pages

    def process_cells(ref_bounds, started_new_page_at_row, offset)
      # Track cells to be drawn on this page. They will all be drawn when this
      # page is finished.
      cells_this_page = []

      split_cells = []
      split_cells_new_page = []

      row_to_split = -1
      splitting = false
      original_height = 0

      @cells.each do |cell|
        puts "@@@ cell #{cell.row}/#{cell.column} content=#{cell.content}"

        if defined?(@split_cells_across_pages) && @split_cells_across_pages && only_plain_text_cells(cell.row)
          
          max_available_height = (cell.y + offset) - ref_bounds.absolute_bottom

          # should the row be split?
          if start_new_page?(cell, offset, ref_bounds, true) && max_available_height > 0
            row_to_split = cell.row
            original_height = cell.height
            splitting = true
          end

          # split cell content and adjust height of cell
          cell = split_cell_content(cell, row_to_split, max_available_height)

          # reset row_to_split variable if we're in the next row
          if row_to_split > -1 && cell.row > row_to_split && !cell.is_a?(Prawn::Table::Cell::SpanDummy)
            row_to_split = -1
          end

          cell_height = cell.calculate_height_ignoring_span
          puts "@@@ cell #{cell.row}/#{cell.column} height=#{cell.height} (ts 66)"

          if cell_height > max_available_height && 
            cell.row > started_new_page_at_row && 
            !split_cells.empty? &&
            !cell.is_a?(Prawn::Table::Cell::SpanDummy)
            puts "@@@ cell #{cell.row}/#{cell.column} entering path 1"
            # recalculate / resplit content for split_cells array
            # this may be necessary because a cell that spans multiple rows did not
            # know anything about needed height changes in subsequent rows when the text was split
            # e.g. original n+1 lines where able to be printed in the remaining space, however
            # a splitting of a later row resulted in a table that was smaller than the theoretical
            # maximum that was used in the original calculation (for example due to the padding)
            # thus the last line can't be printed because there is only space for n lines
            recalculated_split_cells = []
            first_row = split_cells.first.row
            last_row = split_cells.last.row
            # O(n^2) on the cells about to be split
            # maybe we can improve this at some point in the future

            split_cells.each do |split_cell|

              old_height = split_cell.height
              old_y = split_cell.y
              puts "@@@ cell 5/27 cell #{split_cell.row}/#{split_cell.column} height=#{split_cell.height} cell.class=#{split_cell.class} (ts 120)"
              split_cell.height = 0 unless split_cell.is_a?(Prawn::Table::Cell::SpanDummy)
              puts "@@@ cell 5/27 cell #{split_cell.row}/#{split_cell.column} height=#{split_cell.height} (ts 122)"

              max_available_height = rows(first_row..last_row).height

              split_cell_content(split_cell, split_cell.row, max_available_height)

              puts "@@@ cell #{split_cell.row}/#{split_cell.column} height=#{split_cell.height} (ts 145)"
              split_cell.y_offset_new_page = (old_height - split_cell.height) if !split_cell.is_a?(Prawn::Table::Cell::SpanDummy)
            end

            # draw cells on the current page and then start a new one
            # this will also add a header to the new page if a header is set
            # reset array of cells for the new page
            puts "cell 5/27 just before ink_and_draw_cells_and_start_new_page"

            cells_this_page, offset = ink_and_draw_cells_and_start_new_page(cells_this_page, cell, split_cells, offset)
            puts "cell 5/27 just after ink_and_draw_cells_and_start_new_page"

            # any remaining cells to be split will have been split by the ink_and_draw_cells_and_start_new_page command
            # calculate which cells should be shown on the new page
            # -> which shows wheren't fully rendered on the last one
            split_cells_new_page = Prawn::Table::SplitCells.new(split_cells, current_row_number: cell.row).calculate_cells_new_page
            split_cells = []
            splitting=false
            
            # draw split cells on to the new page
            split_cell_height = print_split_cells(split_cells_new_page, cells_this_page, offset - original_height, new_page: true, current_row: cell.row)
            offset -= split_cell_height
            puts "@@@ cell #{cell.row}/#{cell.column} reducing offset by #{split_cell_height} (ts 89)"

            # remember the current row for background coloring
            started_new_page_at_row = cell.row
          end
        elsif start_new_page?(cell, offset, ref_bounds) 
          puts "@@@ cell #{cell.row}/#{cell.column} height=#{cell.height} (ts 105)"
          # draw cells on the current page and then start a new one
          # this will also add a header to the new page if a header is set
          # reset array of cells for the new page
          cells_this_page, offset = ink_and_draw_cells_and_start_new_page(cells_this_page, cell)

          # remember the current row for background coloring
          started_new_page_at_row = cell.row
        end

        # Set background color, if any.
        cell = set_background_color(cell, started_new_page_at_row)

        puts "@@@ cell #{cell.row}/#{cell.column} height=#{cell.height} (ts 140)"
        
        if splitting
          # remember this cell
          split_cells.push cell
        else
          # add the current cell to the cells array for the current page
          puts "@@@ cell #{cell.row}/#{cell.column} height=#{cell.height} (ts 147)"
          cells_this_page << [cell, [cell.relative_x, cell.relative_y(offset)]]
        end
      end
      puts "@@@ cell 5/27 entering final page processing"

      cells_this_page, offset = print_split_cells_on_final_page(split_cells, cells_this_page, offset, splitting)

      # ensure that each cell in each row is of equal height
      skip_header_rows = Hash.new(false)
      header_rows.each do |cell|
        skip_header_rows[cell.row] = true
      end

      cells_this_page.each do |cell, cell_array|
        next if cell.class == Prawn::Table::Cell::SpanDummy
        next if skip_header_rows[cell.row]
        old_height = cell.height
        cell.height = row(cell.row).height
        puts "@@@ cell #{cell.row}/#{cell.column} height=#{cell.height} (ts 127)"
      end

      return cells_this_page, offset
    end

    def print_split_cells_on_final_page(split_cells, cells_this_page, offset, splitting)
      print_split_cells(split_cells, cells_this_page, offset)

      if splitting
        # draw cells on the current page and then start a new one
        # this will also add a header to the new page if a header is set
        # reset array of cells for the new page
        cells_this_page, offset = ink_and_draw_cells_and_start_new_page(cells_this_page, @cells.last)

        # draw split cells on to the new page
        print_split_cells(split_cells, cells_this_page, offset, new_page: true, current_row: @cells.last.row)
      end

      return cells_this_page, offset
    end

    # split the content of the cell
    def split_cell_content(cell, row_to_split, max_available_height)
      # we don't process SpanDummy cells
      return cell if cell.is_a?(Prawn::Table::Cell::SpanDummy)

      return cell unless row_to_split == cell.row

      # the main work
      split_cell = Prawn::Table::SplitCell.new(cell).split(max_available_height)
      return split_cell.cell
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

    def print_split_cells(split_cells, cells_this_page, offset, hash={})
      cells_object = Prawn::Table::SplitCells.new(split_cells, table: self, new_page: hash[:new_page])
      cells_object.adjust_content_for_new_page if hash[:new_page]
      
      @max_cell_height = cells_object.max_cell_heights
      cells_object.adjust_height_of_cells
      
      cells_object.cells.each do |split_cell|
        cells_this_page << print_split_cell(split_cell, cells_object, offset)
      end

      @max_cell_height_cached = cells_object.max_cell_heights(true)
      return (@max_cell_height.values.max || 0)
    end

    def print_split_cell(split_cell, cells_object, offset)
      cell = Prawn::Table::SplitCell.new(split_cell, cells_object)

      # we might have to adjust the offset
      adjust_offset = cell.extra_offset(@max_cell_height_cached, @final_cell_last_page)
       
      # if the offset has to be adjusted, also correct the y position
      split_cell.y = @final_cell_last_page.y if cell.adjust_offset?(@final_cell_last_page)

      cell_for_page = [split_cell, [split_cell.relative_x, split_cell.relative_y(offset - adjust_offset)]]
      
      # it may happen that a row is only present because a text cell rowspans into this page
      # however the row itself is of no use, thus move it off the canvas
      row(split_cell.row).reduce_y(-2000) if cell.move_cells_off_canvas?

      return cell_for_page
    end

    # ink and draw cells, then start a new page
    def ink_and_draw_cells_and_start_new_page(cells_this_page, cell, split_cells=false, offset=false)
      # print any remaining cells to be split
      print_split_cells(split_cells, cells_this_page, offset) if offset

      @final_cell_last_page = split_cells.last if split_cells

      super
    end

  end
end
