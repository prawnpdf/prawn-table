# encoding: utf-8
#
# <b> This is an optional and experimential feature!</b>
#
# While it is known to work in many use cases, it is rather new code and not (yet) widely used, thus
# the possibility for bugs is higher than usual.
#
# To activate this feature you need to pass <i>split_cells_across_pages</i> to the table command.
#
# This will result in cells not being forced to a single page. The text can freely flow to the
# next page.
#
# This feature only supports plain text cells. The cells of rotated text, images and sub tables
# are still forced onto a single page.

require File.expand_path(File.join(File.dirname(__FILE__),
                                   %w[.. example_helper]))

filename = File.basename(__FILE__).gsub('.rb', '.pdf')
Prawn::ManualBuilder::Example.generate(filename) do
  
  # generate some text that will be split across two pages
  lorem_ipsum_string = "This will be a very long cell that is split accross two pages. "
  150.times { |i| lorem_ipsum_string += i.to_s + ' ' }

  data = [ [{ content: lorem_ipsum_string, rowspan: 18, width: 100 },
            { content: "foo 0", height: 30 }]]
  17.times { |i| data.push [{ content: "foo #{i+1}", height: 30 }] }

  table data, split_cells_across_pages: true
end
