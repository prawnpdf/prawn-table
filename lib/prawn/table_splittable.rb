# encoding: utf-8

require_relative 'table/splittable/split_cell'
require_relative 'table/splittable/split_cells'

module Prawn
  class TableSplittable < Table

    # option passed to TableSplittable indicating that this table
    # should split final rows on a page if needed.
    attr_accessor :split_cells_in_final_row

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
        if defined?(@split_cells_in_final_row) && @split_cells_in_final_row && only_plain_text_cells(cell.row)
          
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
          if cell_height > max_available_height && 
            cell.row > started_new_page_at_row && 
            !split_cells.empty? &&
            !cell.is_a?(Prawn::Table::Cell::SpanDummy)
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
              split_cell.height = 0
              puts "@@@ cell #{split_cell.row}/#{split_cell.column} height=#{split_cell.height} (ts 66)"
              max_available_height = rows(first_row..last_row).height

              split_cell_content(split_cell, split_cell.row, max_available_height)
              puts "@@@ cell #{split_cell.row}/#{split_cell.column} height=#{split_cell.height} (ts 70)"
              split_cell.y_offset_new_page = (old_height - split_cell.height) if !split_cell.is_a?(Prawn::Table::Cell::SpanDummy)
            end

            # draw cells on the current page and then start a new one
            # this will also add a header to the new page if a header is set
            # reset array of cells for the new page
            cells_this_page, offset = ink_and_draw_cells_and_start_new_page(cells_this_page, cell, split_cells, offset)

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
      
      compensate_offset_for_height = 0
      extra_height_for_row_dummies = 0

      cells_object = Prawn::Table::SplitCells.new(split_cells, table: self, new_page: hash[:new_page])
      cells_object.adjust_content_for_new_page if hash[:new_page]
      
      @max_cell_height = cells_object.max_cell_heights
      # @max_cell_height_cached = (@max_cell_height_cached || {}).merge @max_cell_height

      # puts "@@@ cell 9/1 merge 1=#{@max_cell_height} 2=#{a} 3=#{@max_cell_height.merge a}"
      
      # puts "@@@ cell 9/1 merge2 1=#{@max_cell_height} 2=#{a} 3=#{@max_cell_height.merge a}"
      # cells_object.adjust_height_of_cells

      split_cells = cells_object.cells
      
      global_offset = 0
      split_cells.each do |split_cell|
        if hash[:new_page]
          puts "@@@ cell #{split_cell.row}/#{split_cell.column} #############"
          puts "@@@ cell #{split_cell.row}/#{split_cell.column} new page"
          puts "@@@ cell #{split_cell.row}/#{split_cell.column} #############"
          puts "@@@ cell #{split_cell.row}/#{split_cell.column} offset = #{offset}"
        end

        unless split_cell.is_a?(Prawn::Table::Cell::SpanDummy)
          # if multiple cells of multiple rows are split it may happen that the cell
          # holding the text (and which will be rendered) is from an earlier row than
          # the last row on the last page (and thus the first row on the new page)
          # in this case set the height of this cell to the first line of the new page
          # otherwise just take the newely calculated row height
          first_row_new_page = @max_cell_height.keys.min || 0

          if split_cell.row < first_row_new_page
            split_cell.height = @max_cell_height[first_row_new_page]
            puts "@@@ cell #{split_cell.row}/#{split_cell.column} height=#{split_cell.height} @max_cell_height=#{@max_cell_height}(ts 203)"
          else
            split_cell.height = @max_cell_height[split_cell.row]
            puts "@@@ cell #{split_cell.row}/#{split_cell.column} height=#{split_cell.height} (ts 206)"
          end
        end

        # rows of dummy cells (may be on old or new page, that's what we filter for)
        row_numbers = split_cell.filtered_dummy_cells(split_cells.last.row, hash[:new_page]).map { |dummy_cell| dummy_cell.row if dummy_cell.row_dummy? }.uniq.compact
        original_height = row_numbers.map { |row_number| row(row_number).height }.inject(:+)
        if hash[:new_page]
          extra_height_for_row_dummies = row_numbers.map { |row_number| row(row_number).recalculate_height }.inject(:+)
        else
          puts "@@@ cell #{split_cell.row}/#{split_cell.column} @max_cell_height=#{@max_cell_height}"
          extra_height_for_row_dummies=row_numbers.map{ |row_number| @max_cell_height[row_number]}.inject(:+)
        end
        
        puts "@@@ cell #{split_cell.row}/#{split_cell.column} extra_height_for_row_dummies=#{extra_height_for_row_dummies}"
        # compensate_offset_for_height = (original_height - extra_height_for_row_dummies) if extra_height_for_row_dummies && extra_height_for_row_dummies > 0

        # # the cell needs to be laid over the dummy cells, that's why we have to increase its height
        split_cell.height += extra_height_for_row_dummies || 0
        puts "@@@ cell #{split_cell.row}/#{split_cell.column} height=#{split_cell.height} row_numbers=#{row_numbers} (ts 218)"

        # puts "@@@ cell #{split_cell.row}/#{split_cell.column} @max_cell_height=#{@max_cell_height} foo=#{foo}"
        # compensate y if necessary
        # split_cell.y += (split_cell.y_offset_new_page || 0) if hash[:new_page] && old_height == split_cell.height && !split_cell.is_a?(Prawn::Table::Cell::SpanDummy)
        # split_cell.y += (split_cell.y_offset_new_page || 0) if hash[:new_page] && !split_cell.is_a?(Prawn::Table::Cell::SpanDummy)

        # ensure that the cells are positioned correctly 
        row_numbers.each do |row_number|
          row(row_number).reduce_y(compensate_offset_for_height)
        end

        #
        # add the split_cell to the cells_this_page array
        #

        # special treatment for a very special case
        if hash[:new_page] && 
           !split_cell.is_a?(Prawn::Table::Cell::SpanDummy) &&
           !split_cell.dummy_cells.empty? && 
           split_cell.row < split_cells.last.row

          # add it to the cells_this_page array and adjust the position accordingly
          # we need to take into account any rows that have already been printed
          # height_of_additional_already_printed_rows = rows((split_cell.row+1)..(split_cells.last.row)).height
          
          # manual merge - only take values that don't exist yet
          @max_cell_height_cached2 = @max_cell_height_cached

          height_of_additional_already_printed_rows = ((split_cell.row+1)..(split_cells.last.row)).map{ |row_number| @max_cell_height_cached2[row_number]}.inject(:+)
          puts "@@@ cell #{split_cell.row}/#{split_cell.column} height_of_additional_already_printed_rows=#{height_of_additional_already_printed_rows} (ts 257)"
          if split_cell.row == 28 && split_cell.column == 0
            # foo = ((split_cell.row+1)..(split_cells.last.row)).map{ |row_number| @max_cell_height[row_number]}.inject(:+)
            foo = 0
            puts "@@@ cell #{split_cell.row}/#{split_cell.column} foo=#{foo} @max_cell_height_cached=#{@max_cell_height_cached} (ts 259)"
            puts "@@@ cell #{split_cell.row}/#{split_cell.column} rows #{split_cell.row+1}..#{split_cells.last.row}}"
            # height_of_additional_already_printed_rows = 23.872
            # height_of_additional_already_printed_rows = 0
          end
          # # if you ever search for an error in the next line, you may want to check if adding split_cell.y_offset_new_page to the value
          # passed to relative_y solves your issue
          puts "@@@ cell #{split_cell.row}/#{split_cell.column} cells_this_page cell.y=#{split_cell.y} cell.relative_y=#{split_cell.relative_y(offset - height_of_additional_already_printed_rows)} (ts 272)"
          cells_this_page << [split_cell, [split_cell.relative_x, split_cell.relative_y(offset - height_of_additional_already_printed_rows)]]

          # move the rest of the row of the canvas
          row(split_cell.row).reduce_y(-2000)

        # standard treatment
        else
          cells_this_page << [split_cell, [split_cell.relative_x, split_cell.relative_y(offset)]] #unless split_cell.content.nil? || split_cell.content.empty?
        end

        global_offset += compensate_offset_for_height
      end

      @max_cell_height_cached = cells_object.max_cell_heights(true)
      puts "cell 27/0 cell 28/0 reloading new @max_cell_height_cached=#{@max_cell_height_cached}"
      return (@max_cell_height.values.max || 0) - (global_offset || 0)
    end

    # ink and draw cells, then start a new page
    def ink_and_draw_cells_and_start_new_page(cells_this_page, cell, split_cells=false, offset=false)
      # print any remaining cells to be split
      print_split_cells(split_cells, cells_this_page, offset) if offset

      super
    end

  end
end
