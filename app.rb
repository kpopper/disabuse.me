require 'sinatra'

get '/' do
  haml :index
end

__END__

@@ index
.title Hello World