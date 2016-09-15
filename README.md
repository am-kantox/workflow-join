# Workflow::Join

[![Build Status](https://travis-ci.org/am-kantox/workflow-join.svg?branch=master)](https://travis-ci.org/am-kantox/workflow-join)


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'workflow-join'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install workflow-join

## Usage

```ruby
class Master
  include Workflow

  attr_accessor :slave

  def initialize(*)
    @slave = Slave.new
  end

  workflow do
    state :meeting do
      event :go, transitions_to: :after_meeting
    end
    state :after_meeting

    # before entering :after_meeting state, wait for @slave to enter :resolved state
    guard :@slave, inner: :after_meeting, outer: :resolved
  end
end

class Slave
  include Workflow

  workflow do
    state :unresolved do
      event :resolve, transitions_to: :resolved
    end
    state :resolved
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/workflow-join. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
