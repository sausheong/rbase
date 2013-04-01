ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/benchmark'

require 'bundler'
Bundler.require
require './rbase'

include Rack::Test::Methods

def app
  Sinatra::Application
end

describe "rbase speed test" do
  
  before do
    10000.times do
      str = (0...8).map{(65+rand(26)).chr}.join
      user = {'name' => str, 'email' => "#{str}@email.com", 'age' => rand(100), 'created_at' => "#{rand(27)+1}-#{rand(10)+1}-1999"}
      post "/User", row: user.to_json      
    end
  end
  
  bench_range { bench_exp 1, 100 }
  bench_performance_linear "find record by id", 0.999 do |n|
    n.times do
      get "/User/1"
      last_response.status.must_equal 200
    end
  end
  
  bench_performance_linear "find record by query - like", 0.999 do |n|
    n.times do
      get '/User/name/like/Jane'
      last_response.status.must_equal 200
    end
  end  
  
  bench_performance_linear "find record by query - integer compare", 0.999 do |n|
    n.times do
      get '/User/age/gt/50?type=integer'
      last_response.status.must_equal 200
    end
  end
  
  bench_performance_linear "find record by query - date compare", 0.999 do |n|
    n.times do
      get '/User/created_at/gt/6-6-1999?type=time'
      last_response.status.must_equal 200
    end
  end  

  bench_performance_linear "insert single record", 0.999 do |n|
    n.times do
      str = (0...8).map{(65+rand(26)).chr}.join
      user = {'name' => str, 'email' => "#{str}@email.com", 'age' => rand(100), 'created_at' => "#{rand(27)+1}-#{rand(10)+1}-1999"}
      post "/User", row: user.to_json
      last_response.status.must_equal 200
    end
  end  

end