framework 'Cocoa'

require 'MultiPart'

class Imgur
  def Imgur.upload(filename)
    multi = MultiPart.alloc.initWithURL(NSURL.URLWithString "http://imgur.com/upload")
    multi["MAX_FILE_SIZE"] = 10485760
    multi["UPLOAD_IDENTIFIER"] = "94mkarkfgcglvpigm5he1s07m4"
    multi["file[]"] = File.new(filename)
    puts multi.request
    
    response = Pointer.new "@"
    error = Pointer.new "@"
    puts 'before upload'
    data = NSURLConnection.sendSynchronousRequest(multi.request, 
                                                  returningResponse:response,
                                                  error:error)
    # dereferencing
    puts 'upload done'
    response = response[0]
    response.URL
  end
end
  
