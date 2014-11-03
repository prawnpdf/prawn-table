# encoding: utf-8

module Prawn
  class Table

    # This class can do one thing well: split the content of a cell
    # while doing this it also adjust the height of the cell to something reasonable
    class SplitCell

    def initialize(cell, cells=false)
      @cell = cell
      @cells = cells
      if cell.content
        @original_content = cell.content
        @content_array = cell.content.split(' ')
      end
    end

    attr_reader :cells

    attr_accessor :cell


    # split the content of the cell and adjust the height
    def split(row_to_split, max_available_height)
      # we don't process SpanDummy cells
      return cell if cell.is_a?(Prawn::Table::Cell::SpanDummy)

      return cell unless row_to_split == cell.row

      # prepare everything for the while loop
      # first we're gonna check if a single word fits the available space
      i = 0
      cell.content = @content_array[0]

      content_that_fits = ''
      while recalculate_height <= max_available_height
        # content from last round
        content_that_fits = content_old_page(i)
        break if @content_array[i].nil?
        i += 1
        cell.content = content_old_page(i)
      end
      
      split_content(content_that_fits, i)
      
      # recalcualte height for the cell in question
      recalculate_height(include_dummy_cells: true)

      return cell
    end

    # should we adjust the offset?
    def adjust_offset?(final_cell_last_page)
      return false unless move_cells_off_canvas?
      (cell.y > final_cell_last_page.y)
    end

    # calculate extra offset
    def extra_offset(max_cell_heights_cached, final_cell_last_page)
      return 0 if adjust_offset?(final_cell_last_page)
      return 0 unless move_cells_off_canvas?
      return height_of_additional_already_printed_rows(cells.last_row, max_cell_heights_cached)
    end

    # should we move the cell off canvas?
    def move_cells_off_canvas?
      cells.new_page && 
       !cell.is_a?(Prawn::Table::Cell::SpanDummy) &&
       !cell.dummy_cells.empty? && 
       cell.row < cells.last_row
    end

    # returns the height of any rows that have already been printed
    def height_of_additional_already_printed_rows(last_row, max_cell_heights_cached)
      ((cell.row+1..last_row)).map{ |row_number| max_cell_heights_cached[row_number]}.inject(:+)
    end

    # return array to be written to cells_this_page
    def print(offset, max_cell_height_cached, final_cell_last_page)
       # we might have to adjust the offset
      adjust_offset = extra_offset(max_cell_height_cached, final_cell_last_page)
       
      # if the offset has to be adjusted, also correct the y position
      cell.y = final_cell_last_page.y if adjust_offset?(final_cell_last_page)

      cell_for_page = [cell, [cell.relative_x, cell.relative_y(offset - adjust_offset)]]
    end

    private

    # recalculates the height of the cell and dummy cells if specified
    def recalculate_height(options = {})
      new_height = cell.recalculate_height_ignoring_span

      return new_height unless options[:include_dummy_cells] == true

      # if a height was set for this cell, use it if the text didn't have to be split
      # cell.height = cell.original_height if cell.content == old_content && !cell.original_height.nil?
      # and its dummy cells
      cell.dummy_cells.each do |dummy_cell|
        dummy_cell.recalculate_height_ignoring_span
      end      
    
      return new_height
    end

    # splits the content
    def split_content(content_that_fits, i)
      # did anything fit at all?
      if !content_that_fits || content_that_fits.length == 0
        cell.content = @original_content
        return
      end

      cell.content = content_that_fits
      cell.content_new_page = calculate_content_new_page(cell, i)
    end

    # return the content for a new page, based on the existing content_new_page
    # and the calculated position in the content array where the cell is now split
    def calculate_content_new_page(cell, i)
      content_new_page = cell.content_new_page
      if !cell.content_new_page.nil? && !(content_new_page(i).nil? || content_new_page(i) == '')
        content_new_page = ' ' + content_new_page 
      end
      content_new_page(i) + (content_new_page   || '' )
    end

    # returns the content that should be printed to the old page
    def content_old_page(i)
      @content_array[0..i].join(' ')
    end

    # returns the content that should be printed to the new page
    def content_new_page(i)
      @content_array[i..-1].join(' ')
    end
  end
end
end