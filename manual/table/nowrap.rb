# encoding: utf-8
#
# Columns specified as nowrap will always fit on to one line forcing others to
# resize as appropriate. If you want to allow wrapping, but ensure it's never
# in the middle of a word use <code>:whitespace</code> as the <code>:nowrap</code> option's value.
#
require File.expand_path(File.join(File.dirname(__FILE__),
                                   %w[.. example_helper]))

filename = File.basename(__FILE__).gsub('.rb', '.pdf')
Prawn::ManualBuilder::Example.generate(filename) do
  text "Normal widths:"
  table([["Blah " * 10, "Blah " * 10]])
  move_down 20

  text "Nowrap widths:"
  table([[make_cell(:content => "Blah " * 11, :nowrap => true), "Blah " * 12]])
  move_down 20

  text "Wide content without nowrap:"
  table([[("wordword" * 7 + " word" * 4), "word " * 10]])
  move_down 20

  text "Wide content with whitespace nowrap:"
  table([[make_cell(:content => ("wordword" * 7 + " word" * 4), :nowrap => :whitespace), "word " * 10]])
  move_down 20
end
