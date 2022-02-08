# Prawn::Table

[![Gem Version](https://badge.fury.io/rb/prawn-table.png)](http://badge.fury.io/rb/prawn-table)
![Build Status](https://github.com/prawnpdf/prawn-table/actions/workflows/ci.yml/badge.svg)
[![Code Climate](https://codeclimate.com/github/prawnpdf/prawn-table.png)](https://codeclimate.com/github/prawnpdf/prawn-table)
![Maintained: PRs accepted](https://img.shields.io/badge/maintained-PRs_accepted-orange.png)

Provides table support for PrawnPDF.

Originally written by Brad Ediger with community contributions.

## Status

This is currently an experimental extraction and is not actively maintained by
the Prawn maintainers. Yet, Prawn maintenance team will help you integrate your pull
requests. Please reach out to the Prawn maintenance team if you are interested
in helping maintaining this project.

## Documentation

A snapshot of Prawn::Table's manual can be found here:
http://prawnpdf.org/prawn-table-manual.pdf

You can also generate a manual yourself by cloning the repository, running
`bundle`, then running `rake manual`.

All the example files in the `manual` folder can be run individually.

## Development priority

The main development priority is refactoring the code in order to reduce its
complexity and thus make it more readable. By doing this, we will be able
to more easily stabilize the codebase, which currently has a high
defect density.

## Feature requests

Additional features are welcome, but I won't find time to implement them myself
anytime soon. If you can implement them yourself simply send a pull request with
any new features. Please be sure to add extensive test cases and documentation
for the new feature.

In case of more complex features it probably would make sense to discuss them in
an issue before you go ahead and implement them.

## Bug reports

Please use the github issue tracker to file bug reports.

If possible include a failing rspec test case with a seperate pull request and
tag it as unresolved and with the issue number. Example:

```` ruby
it 'illustrates my problem', :unresolved, issue: 1 do
  # test
end
````

This way anyone else fixing it will have a clearer understanding of the
problem and can be sure it's fixed.
