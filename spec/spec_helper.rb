$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'workflow/join'

require 'pry'

describe Workflow::Join do
  it 'has a version number' do
    expect(Workflow::Join::VERSION).not_to be nil
  end
end
