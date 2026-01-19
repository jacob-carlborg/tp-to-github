# frozen_string_literal: true

require "bundler/setup"

require "tp_to_github"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
