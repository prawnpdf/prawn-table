## Master

* Enhancement: Allow time values to be added to a table cell. (Michael MacDonald, PR [#103](https://github.com/prawnpdf/prawn-table/pull/103))
* Bugfix: Use the cell's specified font to calculate the cell width. (Jesse Doyle, PR [#60](https://github.com/prawnpdf/prawn-table/pull/60), issue [#42](https://github.com/prawnpdf/prawn-table/issues/42))

## 0.2.3

* Allow padding of subtables to be configurable. PR #44

## 0.2.2

* Updated supported ruby versions to match Prawn. PR #47
* All cells in a rowspan use the background color of the master (i.e., first) cell (#45)

## 0.2.1

* Allow the use of Prawn `2.x`, as it should not break table behavior.

## 0.2.0

* Allow the use of any Prawn `1.x` release from `1.3` onwards.

## 0.1.2

* fixed unnecessary page breaks with centered tables (#22, #23, #24)
* fixed undefined method `y' for nil:NilClass error (#20, #21, #25)

## 0.1.1

* refactored table.rb to increase readability and lower overall code complexity (#15)
* Fixed multi line table headers that involve cells that span multiple columns (#8)
* respect an explicit set table width, given an header with rowspan across all cells (#6)

## 0.1.0

* Fix table wrapping when cells in the last row on a page have a rowpan > 1 (#3,#5)
* First official release after extraction. Based on the table code from Prawn 1.1.0

