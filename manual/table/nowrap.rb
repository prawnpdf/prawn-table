# encoding: utf-8
#
# Columns specified as nowrap will always fit on to one line forcing others to
# resize as appropriate.
#
require File.expand_path(File.join(File.dirname(__FILE__),
                                   %w[.. example_helper]))

filename = File.basename(__FILE__).gsub('.rb', '.pdf')
Prawn::ManualBuilder::Example.generate(filename) do
  text "Normal widths:"
  table([["Blah " * 10, "Blah " * 10]])
  move_down 20

  text "Nowrap widths:"
  table([[make_cell(:content => "Blah " * 12, :nowrap => true), "Blah " * 12]])
  move_down 20
end
