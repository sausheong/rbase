ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'minitest/spec'
require 'rack/test'
require 'bundler'
Bundler.require
require './rbase'

include Rack::Test::Methods

FileUtils.rm('./rbase.index', force: true)

def app
  Sinatra::Application
end

describe 'rbase' do

  before do
    @schema = {
      'User'    => %w(name email age created_at),
      'Article' => %w(title content author created_at)
    }    
    @user1 = { 'name' => 'Jesse James', 'email' => 'jesse@gmail.com', 'age'  => 31, 'created_at' => '10-10-1869' }
    @user2 = { 'name' => 'John Doe', 'email' => 'john@gmail.com', 'age'  => 25, 'created_at' => '12-1-1969' }
    @user3 = { 'name' => 'Jane Smith', 'email' => 'jane@gmail.com', 'age'  => 18, 'created_at' => '17-10-1999' }    
    
    @article1 = { 'title' => 'Lord of the Rings', 'content' => 'Lots and lots of stuff', 'author' => 'JRR Tolkien', 
                  'created_at' => DateTime.parse('26-Dec-1999')}
    @article2 = { 'title' => 'War and Peace', 'content' => 'Plenty long text', 'author' => 'Leo Tolstoy', 
                  'created_at' => DateTime.parse('23-Mar-2020')}                  
  end

  describe "rbase schema" do  
    it "should allow me to post a new schema" do
      post '/schema', schema: @schema.to_json    
      last_response.status.must_equal 200
      
      get "/schema"
      results = JSON.parse last_response.body
      results.keys.must_include "User"
      results.keys.must_include "Article"
      results.values.must_be_instance_of Array
      results.values.each do |item|
        item.must_include "id"
      end
    end
  end

  describe 'rbase insert' do
    
    before do
      post '/schema', schema: @schema.to_json
    end
    
    it "should allow me to insert a record" do
      # insert a single record
      # every posting of a record returns the id of the record in the post response body
      post "/User", row: @user1.to_json
      last_response.status.must_equal 200
      
      # get a single record by its index
      get "/User/#{last_response.body}"
      results = JSON.parse last_response.body
      results['name'].must_equal 'Jesse James'
    end
  
    it "should allow me to query a table" do
      post "/User", row: @user2.to_json
      last_response.status.must_equal 200
      post "/User", row: @user3.to_json
      last_response.status.must_equal 200

      # exact query
      get "/User/name/is/John%20Doe"
      results = JSON.parse last_response.body
      results.first['name'].must_equal 'John Doe'

      # compare query
      # note the type is needed if the value is considered a different type
      get "/User/age/lt/30?type=integer"
      results = JSON.parse last_response.body
      results.size.must_equal 2
      
      # like query
      get "/User/name/like/Jane"
      results = JSON.parse last_response.body
      results.first['name'].must_equal 'Jane Smith'
    end
    
    it 'should allow me to query dates' do
      post "/Article", row: @article1.to_json
      last_response.status.must_equal 200
      post "/Article", row: @article2.to_json
      last_response.status.must_equal 200     
      
      get "/Article/created_at/lt/15-Aug-2013?type=time"
      results = JSON.parse last_response.body
      results.first['title'].must_equal "Lord of the Rings"      

      get "/Article/created_at/gt/15-Aug-2013?type=time"
      results = JSON.parse last_response.body
      results.first['title'].must_equal "War and Peace"       
    end    
  end

  describe 'rbase update' do
    before do
      post '/schema', schema: @schema.to_json
      post "/User", row: @user1.to_json
      @id = last_response.body
    end
    
    it 'show show change after update' do      
      get "/User/#{@id}"
      results = JSON.parse last_response.body
      results['name'].must_equal 'Jesse James'
      
      changes = {"name" => "Jolly Roger", "age" => 50}
      put "/User/#{@id}", row: changes.to_json
      last_response.body.must_equal @id
      
      get "/User/#{@id}"
      results = JSON.parse last_response.body
      results['name'].must_equal 'Jolly Roger'
      results['age'].must_equal 50
    end

    it 'should show that the row is removed after delete' do
      get "/User/#{@id}"
      results = JSON.parse last_response.body
      results['name'].must_equal 'Jesse James'

      # remove the row
      delete "/User/#{@id}"
      last_response.status.must_equal 200
      
      # try to get the same row
      # it should raise a RuntimeError with the message 'Row not found'
      not_found = lambda {  get "/User/#{@id}" }
      not_found.must_raise RuntimeError
      error = not_found.call rescue $!
      error.message.must_equal "Row not found"
    end
  end
  
end