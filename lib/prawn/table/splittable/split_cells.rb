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
        @cells_this_page_option = options[:cells_this_page]
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

      attr_reader :new_page

      # change content to the one needed for the new page
      def adjust_content_for_new_page
        cells.each do |cell|
          cell = handle_cells_this_page(cell)
          cell.content = cell.content_new_page
        end
      end

      # cells_this_page and split_cells are formatted differently
      # adjust accordingly for cells.each calls
      def handle_cells_this_page(cell)
        return cell[0] if @cells_this_page_option
        return cell
      end

      # adjust the height of the cells
      def adjust_height_of_cells(options = {})
        cells_we_have_passed = []
        @cells.each do |cell|
          cell = handle_cells_this_page(cell)

          next if options[:skip_rows] && options[:skip_rows].include?(cell.row)

          # remember that we've passed this cell (for future dummy cells)
          #
          # ensure that the array is two dimensional
          cells_we_have_passed[cell.row]=[] if cells_we_have_passed[cell.row].nil?
          # remember
          cells_we_have_passed[cell.row][cell.column] = true
          # skip cell if it is a dummy cell not included in the set of cells we
          # are looping through
          if cell.is_a?(Prawn::Table::Cell::SpanDummy)
            master_cell = cell.master_cell
            next if cells_we_have_passed[master_cell.row].nil? || cells_we_have_passed[master_cell.row][master_cell.column].nil?
          end

          # height of the current cell
          height_of_cell = max_row_height(cell) || 0
          puts "cell #{cell.row}/#{cell.column} height=#{height_of_cell} (sc 69)"
          if options[:min_row_height] && !cell.is_a?(Prawn::Table::Cell::SpanDummy) && cell.row != last_row
            min_row_height = options[:min_row_height][cell.row] || 0
            height_of_cell =  min_row_height if min_row_height > height_of_cell
          end

          puts "cell #{cell.row}/#{cell.column} height=#{height_of_cell} (sc 75)"
          puts "cell #{cell.row}/#{cell.column} min_row_height=#{options[:min_row_height]} (sc 76)"
          puts "cell #{cell.row}/#{cell.column} extra_height_for_row_dummies=#{extra_height_for_row_dummies(cell)} (sc 77)"

          row_dummies_height = extra_height_for_row_dummies(cell)
          if !@new_page && options[:min_row_height]
            #row_dummies_height = 93+30
            min_height = 0
            cell.filtered_dummy_cells(last_row, @new_page).each do |dummy_cell|
              next unless dummy_cell.column == cell.column
              if dummy_cell.row != last_row
                puts "cell #{cell.row}/#{cell.column} adding dummy height for row #{dummy_cell.row} of #{options[:min_row_height][dummy_cell.row] || 0}"
                min_height += options[:min_row_height][dummy_cell.row] || 0
              else
                min_height += row(dummy_cell.row).height
              end
            end
            row_dummies_height = min_height if min_height > row_dummies_height
          end


          # account for other rows that this cell spans
          cell.height = height_of_cell + row_dummies_height
        end
      end

      # we don't want to resize header cells and cells from earlier pages
      # (that span into the current one) on the final page
      def adjust_height_of_final_cells(header_rows, first_row_new_page, options = {})
        skip_row_numbers = []
        # don't resize the header
        header_rows.each do |cell|
          skip_row_numbers.push cell.row
        end
        # don't resize cells from former pages (that span into this page)
        0..first_row_new_page.times do |i|
          skip_row_numbers.push i
        end
        skip_row_numbers.uniq!

        cells.each do |cell, stuff|
          puts "cell #{cell.row}/#{cell.column} height=#{cell.height_of_cell} (sc 116)"
        end

        options[:skip_rows] = skip_row_numbers
        adjust_height_of_cells(options)

        cells.each do |cell, stuff|
          puts "cell #{cell.row}/#{cell.column} height=#{cell.height_of_cell} (sc 122)"
        end


        return cells
      end

      # calculate the maximum height of each row
      def max_cell_heights(force_reload = false)
        # cache the result
        return @max_cell_heights if !force_reload && defined? @max_cell_heights

        @max_cell_heights = Hash.new(0)
        cells.each do |cell|
          cell = handle_cells_this_page(cell)
          next if cell.content.nil? || cell.content.empty? 

          # if we are on the new page, change the content of the cell
          # cell.content = cell.content_new_page if hash[:new_page]

          # calculate the height of the cell includign any cells it may span
          respect_original_height = true unless @new_page
          cell_height = cell.calculate_height_ignoring_span(respect_original_height)

          # account for the height of any rows this cell spans (new page)
          cell_height -= height_of_row_dummies(cell)

          @max_cell_heights[cell.row] = cell_height if @max_cell_heights[cell.row] < cell_height
        end
        
        @max_cell_heights
      end
      
      attr_accessor :compensate_offset_for_height

      # calculate by how much we have to compensate the offset
      def compensate_offset
        (max_cell_height.values.max || 0) - compensate_offset_for_height
      end

      # remove any cells from the cells array that are not needed on the new page
      def cells_new_page
        # is there some content to display coming from the last row on the last page?
        # found_some_content_in_the_last_row_on_the_last_page = false
        # cells.each do |split_cell|
        #   next unless split_cell.row == last_row_number_last_page
        #   found_some_content_in_the_last_row_on_the_last_page = true unless split_cell.content_new_page.nil? || split_cell.content_new_page.empty?
        # end

        cells_new_page = []
        cells.each do |split_cell|
          split_cell = handle_cells_this_page(split_cell)
          next if irrelevant_cell?(split_cell)

          # all tests passed. print it - meaning add it to the array
          cells_new_page.push split_cell
        end

        cells_new_page
      end

      # return the cells to be used on the old page
      def cells_old_page
        # obviously we wouldn't have needed a function for this,
        # but it makes the code more readable at the place
        # that calls this function
        cells
      end

      # the number of the first row
      def first_row
        return cells.first[0].row if @cells_this_page_option
        cells.first.row
      end

      # the number of the last row
      def last_row
        return cells.last[0].row if @cells_this_page_option
        cells.last.row
      end

      # resplit the content
      # meaning that we ensure that the content really fits
      # into the cell on the old page and resplit it if necessary
      def resplit_content
        cells.each do |cell|
          cell.height = 0 unless cell.is_a?(Prawn::Table::Cell::SpanDummy)

          max_available_height = rows(first_row..last_row).height

          Prawn::Table::SplitCell.new(cell).split(cell.row, max_available_height)
        end
        return cells
      end

      def min_y
        last_row_last_page = 0
        if @new_page && !cells.empty?
          min_y = nil
          compensate_height = 0
          cells.each do |c, stuff|
            if min_y.nil? || min_y > stuff[1]
              min_y = stuff[1] 
              compensate_height = c.height
            end
          end
        end
        return (min_y || 0) - (compensate_height || 0)
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

      # how much height should we allocated for the rows that are spanned by
      # the row dummies
      def extra_height_for_row_dummies(cell)
        relevant_cells = cell.filtered_dummy_cells(last_row, @new_page)
        row_numbers = calculate_row_numbers(relevant_cells)
        puts "cell #{cell.row}/#{cell.column} row_numbers=#{row_numbers} #{rows([13,14]).height} #{max_cell_heights(true)[13]}"
        return new_height_of_row_dummies(row_numbers) || 0
      end

      # recalculate the height of the rows in question
      def new_height_of_row_dummies(row_numbers)
        if @new_page
          return rows(row_numbers).height
          # return row_numbers.map { |row_number| row(row_number).recalculate_height }.inject(:+)
        else
          return row_numbers.map{ |row_number| max_cell_heights[row_number]}.inject(:+)
        end
      end

      # sets the height of the cell to the maximum of all given cells
      def max_row_height(cell)
        return if cell.is_a?(Prawn::Table::Cell::SpanDummy)

        # if multiple cells of multiple rows are split it may happen that the cell
        # holding the text (and which will be rendered) is from an earlier row than
        # the last row on the last page (and thus the first row on the new page)
        # in this case set the height of this cell to the first line of the new page
        # otherwise just take the newely calculated row height
        first_row_new_page = max_cell_heights.keys.min || 0

        if cell.row < first_row_new_page
          return max_cell_heights[first_row_new_page]
        else
          return max_cell_heights[cell.row]
        end
      end

      # calculate the height of all rows that the dummy cells of the given cell span
      def height_of_row_dummies(cell)
        height = 0
        row_numbers = calculate_row_numbers(cell.dummy_cells)
        row_numbers.each do |row_number|
          height += row(row_number).height
        end
        return height
      end

      # return the numbers of all rows in the given set of cells
      def calculate_row_numbers(cells)
        cells.map { |dummy_cell| dummy_cell.row if dummy_cell.row_dummy? }.uniq.compact
      end
    end
  end
end