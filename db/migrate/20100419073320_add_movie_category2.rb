class AddMovieCategory2 < ActiveRecord::Migration
  def self.up
  	long = Category.new
  	long.name = "Full-Length"
  	long.domain = Category::DOMAIN_MOVIES
  	long.save
  	short = Category.new
  	short.name = "Shorts"
  	short.domain = Category::DOMAIN_MOVIES
  	short.save
  	mock = Category.new
  	mock.name = "Mock-ups"
  	mock.domain = Category::DOMAIN_MOVIES
  	mock.save 
  	
  	Movie.all.each do |m|
  		if m.length and m.length < 180
  			m.category = short
  			m.save
  		elsif m.length and m.length >= 180
  			m.category = long
  			m.save
  		end
  	end
  end

  def self.down
  end
end
