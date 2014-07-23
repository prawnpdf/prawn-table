# Prawn::Table

[![Gem
Version](https://badge.fury.io/rb/prawn-table.png)](http://badge.fury.io/rb/prawn-table)
[![Build
Status](https://secure.travis-ci.org/prawnpdf/prawn-table.png)](http://travis-ci.org/prawnpdf/prawn-table)
[![Code Climate](https://codeclimate.com/github/prawnpdf/prawn-table.png)](https://codeclimate.com/github/prawnpdf/prawn-table)

Provides table support for PrawnPDF. 

Originally written by Brad Ediger with community contributions, now maintained
by Hartwig Brandl with help from the Prawn maintenance team.

This is currently an experimental extraction, more news to come!

## development priority
The main development priority is refactoring the code in order to reduce its complexity and thus make it more readable.

## feature requests
Additional features are welcome, but I won't find time to implement them myself anytime soon. If you can implement them yourself simply send a pull request with any new features. Please be sure to add extensive test cases and documentation for the new feature.

In case of more complex features it probably would make sense to discuss them in an issue before you go ahead and implement them.

## bug reports
Please use the github issue tracker to file bug reports.

If possible include a failing rspec test case with a seperate pull request and tag it as unresolved and with the issue number. Example:
```` ruby
it 'illustrates my problem', :unresolved, issue: 1 do
  # test
end
````
This way I or anyone else fixing it will have a clearer understanding of the problem and can be sure it's fixed.
