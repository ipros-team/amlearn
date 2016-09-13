require 'rspec'
require 'amlearn/version'

include Amlearn

def capture_stdout
  out = StringIO.new
  $stdout = out
  yield
  return out.string
ensure
  $stdout = STDOUT
end

def capture_stderr
  out = StringIO.new
  $stderr = out
  yield
  return out.string
ensure
  $stderr = STDERR
end

def clear_env
  ENV['PASSPHRASE'] = nil
end
